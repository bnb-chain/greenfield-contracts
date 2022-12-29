pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interface/IBEP20.sol";
import "../Config.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee) external;
}

contract TokenHub is Config, OwnableUpgradeable {
    using RLPEncode for *;
    using RLPDecode for *;

    using RLPDecode for RLPDecode.RLPItem;
    using RLPDecode for RLPDecode.Iterator;

    // BSC to INS
    struct TransferOutSynPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        uint256[] amounts;
        address[] recipients;
        address[] refundAddrs;
    }

    // INS to BSC
    struct TransferOutAckPackage {
        address contractAddr;
        uint256[] refundAmounts;
        address[] refundAddrs;
        uint32 status;
    }

    // INS to BSC
    struct TransferInSynPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        uint256 amount;
        address recipient;
        address refundAddr;
    }

    // BSC to INS
    struct TransferInRefundPackage {
        bytes32 bep2TokenSymbol;
        uint256 refundAmount;
        address refundAddr;
        uint32 status;
    }

    // transfer in channel
    uint8 constant public   TRANSFER_IN_SUCCESS = 0;
    uint8 constant public   TRANSFER_IN_FAILURE_TIMEOUT = 1;
    uint8 constant public   TRANSFER_IN_FAILURE_UNBOUND_TOKEN = 2;
    uint8 constant public   TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE = 3;
    uint8 constant public   TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT = 4;
    uint8 constant public   TRANSFER_IN_FAILURE_UNKNOWN = 5;

    uint256 constant public MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
    uint8 constant public   MINIMUM_BEP20_SYMBOL_LEN = 2;
    uint8 constant public   MAXIMUM_BEP20_SYMBOL_LEN = 8;
    bytes32 constant public BEP2_TOKEN_SYMBOL_FOR_BNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
    uint256 constant public MAX_GAS_FOR_CALLING_BEP20=50000;
    uint256 constant public MAX_GAS_FOR_TRANSFER_BNB=10000;

    uint256 constant public INIT_MINIMUM_RELAY_FEE =2e15;
    uint256 constant public REWARD_UPPER_LIMIT =1e18;

    address public CROSS_CHAIN_CONTRACT;
    uint256 public relayFee;

    mapping(address => uint256) public bep20ContractDecimals;
    mapping(address => bytes32) private contractAddrToBEP2Symbol;
    mapping(bytes32 => address) private bep2SymbolToContractAddr;

    event TransferInSuccess(address bep20Addr, address refundAddr, uint256 amount);
    event TransferOutSuccess(address bep20Addr, address senderAddr, uint256 amount, uint256 relayFee);
    event RefundSuccess(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event RefundFailure(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event RewardTo(address to, uint256 amount);
    event ReceiveDeposit(address from, uint256 amount);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);


    function initialize() public initializer {
        __Ownable_init();

        relayFee = INIT_MINIMUM_RELAY_FEE;
        bep20ContractDecimals[address(0x0)] = 18; // BNB decimals is 18
    }

    receive() external payable{
        if (msg.value>0) {
            emit ReceiveDeposit(msg.sender, msg.value);
        }
    }

    function getMiniRelayFee() external view returns(uint256) {
        return relayFee;
    }

    /**
     * @dev handle sync cross-chain package from BSC to INS
   *
   * @param channelId The channel for cross-chain communication
   * @param msgBytes The rlp encoded message bytes sent from BSC to INS
   */
    function handleSynPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external returns(bytes memory) {
        if (channelId == TRANSFER_IN_CHANNELID) {
            return handleTransferInSynPackage(msgBytes);
        } else {
            // should not happen
            require(false, "unrecognized syn package");
            return new bytes(0);
        }
    }

    /**
     * @dev handle ack cross-chain package from INS，it means cross-chain transfer successfully to INS
   * and will refund the remaining token caused by different decimals between BSC and INS.
   *
   * @param channelId The channel for cross-chain communication
   * @param msgBytes The rlp encoded message bytes sent from INS
   */
    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external {
        if (channelId == TRANSFER_OUT_CHANNELID) {
            handleTransferOutAckPackage(msgBytes);
        } else {
            emit UnexpectedPackage(channelId, msgBytes);
        }
    }

    /**
     * @dev handle failed ack cross-chain package from INS, it means failed to cross-chain transfer to INS and will refund the token.
   *
   * @param channelId The channel for cross-chain communication
   * @param msgBytes The rlp encoded message bytes sent from INS
   */
    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external {
        if (channelId == TRANSFER_OUT_CHANNELID) {
            handleTransferOutFailAckPackage(msgBytes);
        } else {
            emit UnexpectedPackage(channelId, msgBytes);
        }
    }

    function decodeTransferInSynPackage(bytes memory msgBytes) internal pure returns (TransferInSynPackage memory, bool) {
        TransferInSynPackage memory transInSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx=0;
        while (iter.hasNext()) {
            if (idx == 0) transInSynPkg.bep2TokenSymbol       = bytes32(iter.next().toUint());
            else if (idx == 1) transInSynPkg.contractAddr     = iter.next().toAddress();
            else if (idx == 2) transInSynPkg.amount           = iter.next().toUint();
            else if (idx == 3) transInSynPkg.recipient        = ((iter.next().toAddress()));
            else if (idx == 4) transInSynPkg.refundAddr       = iter.next().toAddress();
            else break;
            idx++;
        }
        return (transInSynPkg, success);
    }

    function encodeTransferInRefundPackage(TransferInRefundPackage memory transInAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](4);
        elements[0] = uint256(transInAckPkg.bep2TokenSymbol).encodeUint();
        elements[1] = transInAckPkg.refundAmount.encodeUint();
        elements[2] = transInAckPkg.refundAddr.encodeAddress();
        elements[3] = uint256(transInAckPkg.status).encodeUint();
        return elements.encodeList();
    }

    function handleTransferInSynPackage(bytes memory msgBytes) internal returns(bytes memory) {
        (TransferInSynPackage memory transInSynPkg, bool success) = decodeTransferInSynPackage(msgBytes);
        require(success, "unrecognized transferIn package");
        uint32 resCode = doTransferIn(transInSynPkg);
        if (resCode != TRANSFER_IN_SUCCESS) {
            TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage({
            bep2TokenSymbol: transInSynPkg.bep2TokenSymbol,
            refundAmount: transInSynPkg.amount,
            refundAddr: transInSynPkg.refundAddr,
            status: resCode
            });
            return encodeTransferInRefundPackage(transInAckPkg);
        } else {
            return new bytes(0);
        }
    }

    function doTransferIn(TransferInSynPackage memory transInSynPkg) internal returns (uint32) {
        if (transInSynPkg.contractAddr==address(0x0)) {
            if (address(this).balance < transInSynPkg.amount) {
                return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
            }
            (bool success, ) = transInSynPkg.recipient.call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: transInSynPkg.amount}("");
            if (!success) {
                return TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT;
            }
            emit TransferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
            return TRANSFER_IN_SUCCESS;
        } else {
            if (contractAddrToBEP2Symbol[transInSynPkg.contractAddr]!= transInSynPkg.bep2TokenSymbol) {
                return TRANSFER_IN_FAILURE_UNBOUND_TOKEN;
            }
            uint256 actualBalance = IBEP20(transInSynPkg.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP20}(address(this));
            if (actualBalance < transInSynPkg.amount) {
                return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
            }
            bool success = IBEP20(transInSynPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP20}(transInSynPkg.recipient, transInSynPkg.amount);
            if (success) {
                emit TransferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
                return TRANSFER_IN_SUCCESS;
            } else {
                return TRANSFER_IN_FAILURE_UNKNOWN;
            }
        }
    }

    function decodeTransferOutAckPackage(bytes memory msgBytes) internal pure returns(TransferOutAckPackage memory, bool) {
        TransferOutAckPackage memory transOutAckPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx=0;
        while (iter.hasNext()) {
            if (idx == 0) {
                transOutAckPkg.contractAddr = iter.next().toAddress();
            }
            else if (idx == 1) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutAckPkg.refundAmounts = new uint256[](list.length);
                for (uint256 index=0; index<list.length; index++) {
                    transOutAckPkg.refundAmounts[index] = list[index].toUint();
                }
            }
            else if (idx == 2) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutAckPkg.refundAddrs = new address[](list.length);
                for (uint256 index=0; index<list.length; index++) {
                    transOutAckPkg.refundAddrs[index] = list[index].toAddress();
                }
            }
            else if (idx == 3) {
                transOutAckPkg.status = uint32(iter.next().toUint());
                success = true;
            }
            else {
                break;
            }
            idx++;
        }
        return (transOutAckPkg, success);
    }

    function handleTransferOutAckPackage(bytes memory msgBytes) internal {
        (TransferOutAckPackage memory transOutAckPkg, bool decodeSuccess) = decodeTransferOutAckPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut ack package");
        doRefund(transOutAckPkg);
    }

    function doRefund(TransferOutAckPackage memory transOutAckPkg) internal {
        if (transOutAckPkg.contractAddr==address(0x0)) {
            for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++) {
                (bool success, ) = transOutAckPkg.refundAddrs[index].call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: transOutAckPkg.refundAmounts[index]}("");
                if (!success) {
                    emit RefundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
                } else {
                    emit RefundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
                }
            }
        } else {
            for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++) {
                bool success = IBEP20(transOutAckPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP20}(transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
                if (success) {
                    emit RefundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
                } else {
                    emit RefundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
                }
            }
        }
    }

    function decodeTransferOutSynPackage(bytes memory msgBytes) internal pure returns (TransferOutSynPackage memory, bool) {
        TransferOutSynPackage memory transOutSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx=0;
        while (iter.hasNext()) {
            if (idx == 0) {
                transOutSynPkg.bep2TokenSymbol = bytes32(iter.next().toUint());
            } else if (idx == 1) {
                transOutSynPkg.contractAddr = iter.next().toAddress();
            } else if (idx == 2) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.amounts = new uint256[](list.length);
                for (uint256 index=0; index<list.length; index++) {
                    transOutSynPkg.amounts[index] = list[index].toUint();
                }
            } else if (idx == 3) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.recipients = new address[](list.length);
                for (uint256 index=0; index<list.length; index++) {
                    transOutSynPkg.recipients[index] = list[index].toAddress();
                }
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.refundAddrs = new address[](list.length);
                for (uint256 index=0; index<list.length; index++) {
                    transOutSynPkg.refundAddrs[index] = list[index].toAddress();
                }
            } else {
                break;
            }
            idx++;
        }
        return (transOutSynPkg, success);
    }

    function handleTransferOutFailAckPackage(bytes memory msgBytes) internal {
        (TransferOutSynPackage memory transOutSynPkg, bool decodeSuccess) = decodeTransferOutSynPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut syn package");
        TransferOutAckPackage memory transOutAckPkg;
        transOutAckPkg.contractAddr = transOutSynPkg.contractAddr;
        transOutAckPkg.refundAmounts = transOutSynPkg.amounts;
        uint256 bep20TokenDecimals = bep20ContractDecimals[transOutSynPkg.contractAddr];
        for (uint idx=0;idx<transOutSynPkg.amounts.length;idx++) {
            transOutSynPkg.amounts[idx] = transOutSynPkg.amounts[idx];
        }
        transOutAckPkg.refundAddrs = transOutSynPkg.refundAddrs;
        transOutAckPkg.status = TRANSFER_IN_FAILURE_UNKNOWN;
        doRefund(transOutAckPkg);
    }

    function encodeTransferOutSynPackage(TransferOutSynPackage memory transOutSynPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](5);

        elements[0] = uint256(transOutSynPkg.bep2TokenSymbol).encodeUint();
        elements[1] = transOutSynPkg.contractAddr.encodeAddress();

        uint256 batchLength = transOutSynPkg.amounts.length;

        bytes[] memory amountsElements = new bytes[](batchLength);
        for (uint256 index = 0; index< batchLength; index++) {
            amountsElements[index] = transOutSynPkg.amounts[index].encodeUint();
        }
        elements[2] = amountsElements.encodeList();

        bytes[] memory recipientsElements = new bytes[](batchLength);
        for (uint256 index = 0; index< batchLength; index++) {
            recipientsElements[index] = transOutSynPkg.recipients[index].encodeAddress();
        }
        elements[3] = recipientsElements.encodeList();

        bytes[] memory refundAddrsElements = new bytes[](batchLength);
        for (uint256 index = 0; index< batchLength; index++) {
            refundAddrsElements[index] = transOutSynPkg.refundAddrs[index].encodeAddress();
        }
        elements[4] = refundAddrsElements.encodeList();
        return elements.encodeList();
    }

    /**
     * @dev request a cross-chain transfer from BSC to INS
   *
   * @param contractAddr The token contract which is transferred
   * @param recipient The destination address of the cross-chain transfer on INS.
   * @param amount The amount to transfer
   */
    function transferOut(address contractAddr, address recipient, uint256 amount) external payable returns (bool) {
        bytes32 bep2TokenSymbol;
        uint256 rewardForRelayer;
        if (contractAddr==address(0x0)) {
            require(msg.value>=amount + relayFee, "received BNB amount should be no less than the sum of transferOut BNB amount and minimum relayFee");
            rewardForRelayer=msg.value - amount;
            bep2TokenSymbol=BEP2_TOKEN_SYMBOL_FOR_BNB;
        } else {
            bep2TokenSymbol = contractAddrToBEP2Symbol[contractAddr];
            require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bound to any bep2 token");
            require(msg.value>=relayFee, "received BNB amount should be no less than the minimum relayFee");
            rewardForRelayer=msg.value;
            uint256 bep20TokenDecimals=bep20ContractDecimals[contractAddr];
            require(IBEP20(contractAddr).transferFrom(msg.sender, address(this), amount));
        }
        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage({
            bep2TokenSymbol: bep2TokenSymbol,
            contractAddr: contractAddr,
            amounts: new uint256[](1),
            recipients: new address[](1),
            refundAddrs: new address[](1)
        });
        transOutSynPkg.amounts[0]=amount;
        transOutSynPkg.recipients[0]=recipient;
        transOutSynPkg.refundAddrs[0]=msg.sender;
        ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(TRANSFER_OUT_CHANNELID, encodeTransferOutSynPackage(transOutSynPkg), rewardForRelayer);
        emit TransferOutSuccess(contractAddr, msg.sender, amount, rewardForRelayer);
        return true;
    }

    function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view returns(address) {
        return bep2SymbolToContractAddr[bep2Symbol];
    }

    function getBep2SymbolByContractAddr(address contractAddr) external view returns(bytes32) {
        return contractAddrToBEP2Symbol[contractAddr];
    }

    function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external onlyTokenManager {
        bep2SymbolToContractAddr[bep2Symbol] = contractAddr;
        contractAddrToBEP2Symbol[contractAddr] = bep2Symbol;
        bep20ContractDecimals[contractAddr] = decimals;
    }

    function unbindToken(bytes32 bep2Symbol, address contractAddr) external onlyTokenManager {
        delete bep2SymbolToContractAddr[bep2Symbol];
        delete contractAddrToBEP2Symbol[contractAddr];
    }

    function isMiniBEP2Token(bytes32 symbol) internal pure returns(bool) {
        bytes memory symbolBytes = new bytes(32);
        assembly {
            mstore(add(symbolBytes, 32), symbol)
        }
        uint8 symbolLength = 0;
        for (uint8 j = 0; j < 32; j++) {
            if (symbolBytes[j] != 0) {
                symbolLength++;
            } else {
                break;
            }
        }
        if (symbolLength < MINIMUM_BEP20_SYMBOL_LEN + 5) {
            return false;
        }
        if (symbolBytes[symbolLength-5] != 0x2d) { // '-'
            return false;
        }
        if (symbolBytes[symbolLength-1] != 'M') { // AINS-XXXM
            return false;
        }
        return true;
    }

    function getBoundContract(string memory bep2Symbol) public view returns (address) {
        bytes32 bep2TokenSymbol;
        assembly {
            bep2TokenSymbol := mload(add(bep2Symbol, 32))
        }
        return bep2SymbolToContractAddr[bep2TokenSymbol];
    }

    function getBoundBep2Symbol(address contractAddr) public view returns (string memory) {
        bytes32 bep2SymbolBytes32 = contractAddrToBEP2Symbol[contractAddr];
        bytes memory bep2SymbolBytes = new bytes(32);
        assembly {
            mstore(add(bep2SymbolBytes,32), bep2SymbolBytes32)
        }
        uint8 bep2SymbolLength = 0;
        for (uint8 j = 0; j < 32; j++) {
            if (bep2SymbolBytes[j] != 0) {
                bep2SymbolLength++;
            } else {
                break;
            }
        }
        bytes memory bep2Symbol = new bytes(bep2SymbolLength);
        for (uint8 j = 0; j < bep2SymbolLength; j++) {
            bep2Symbol[j] = bep2SymbolBytes[j];
        }
        return string(bep2Symbol);
    }
}

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../Config.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../interface/IGovHub.sol";

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 synRelayFee, uint256 ackRelayFee) external;
}

contract TokenHub is Config, OwnableUpgradeable {
    using RLPEncode for *;
    using RLPDecode for *;

    using RLPDecode for RLPDecode.RLPItem;
    using RLPDecode for RLPDecode.Iterator;

    /************************* constant *************************/
    // transfer in channel
    uint8 constant public   TRANSFER_IN_SUCCESS = 0;
    uint8 constant public   TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE = 1;
    uint8 constant public   TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT = 2;
    uint8 constant public   TRANSFER_IN_FAILURE_UNKNOWN = 3;

    uint256 constant public MAX_GAS_FOR_TRANSFER_BNB = 10000;

    /************************* storage layer *************************/
    address public govHub;
    uint256 public synRelayFee;
    uint256 public ackRelayFee;

    /************************* struct / event *************************/
    // BSC to INS
    struct TransferOutSynPackage {
        uint256 amount;
        address recipient;
        address refundAddr;
    }

    // INS to BSC
    struct TransferOutAckPackage {
        uint256 refundAmount;
        address refundAddr;
        uint32 status;
    }

    // INS to BSC
    struct TransferInSynPackage {
        uint256 amount;
        address recipient;
        address refundAddr;
    }

    // BSC to INS
    struct TransferInRefundPackage {
        uint256 refundAmount;
        address refundAddr;
        uint32 status;
    }

    event TransferInSuccess(address refundAddr, uint256 amount);
    event TransferOutSuccess(address senderAddr, uint256 amount, uint256 synRelayFee, uint256 ackRelayFee);
    event RefundSuccess(address refundAddr, uint256 amount, uint32 status);
    event RefundFailure(address refundAddr, uint256 amount, uint32 status);
    event RewardTo(address to, uint256 amount);
    event ReceiveDeposit(address from, uint256 amount);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

    modifier onlyCrossChainContract() {
        require(msg.sender == IGovHub(govHub).crosschain(), "only cross chain contract");
        _;
    }

    /************************* external / public function *************************/
    function initialize(address _govHub) public initializer {
        require(_govHub != address (0), "zero govHub");
        __Ownable_init();

        govHub = _govHub;

        synRelayFee = 2e15;
        ackRelayFee = 2e15;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit ReceiveDeposit(msg.sender, msg.value);
        }
    }

    /**
     * @dev handle sync cross-chain package from BSC to INS
   *
   * @param channelId The channel for cross-chain communication
   * @param msgBytes The rlp encoded message bytes sent from BSC to INS
   */
    function handleSynPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external returns (bytes memory) {
        if (channelId == TRANSFER_IN_CHANNELID) {
            return _handleTransferInSynPackage(msgBytes);
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
            _handleTransferOutAckPackage(msgBytes);
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
            _handleTransferOutFailAckPackage(msgBytes);
        } else {
            emit UnexpectedPackage(channelId, msgBytes);
        }
    }

    /**
     * @dev request a cross-chain transfer from BSC to INS
   *
   * @param recipient The destination address of the cross-chain transfer on INS.
   * @param amount The amount to transfer
   */
    function transferOut(address recipient, uint256 amount) external payable returns (bool) {
        require(msg.value >= amount + synRelayFee + ackRelayFee, "received BNB amount should be no less than the sum of transferOut BNB amount and minimum relayFee");
        uint256 _ackRelayFee = msg.value - amount - synRelayFee;

        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage({
            amount: amount,
            recipient: recipient,
            refundAddr: msg.sender
        });

        address _crosschain = IGovHub(govHub).crosschain();
        ICrossChain(_crosschain).sendSynPackage(TRANSFER_OUT_CHANNELID, _encodeTransferOutSynPackage(transOutSynPkg), synRelayFee, _ackRelayFee);
        emit TransferOutSuccess(msg.sender, amount, synRelayFee, _ackRelayFee);
        return true;
    }

    /************************* internal function *************************/
    function _decodeTransferInSynPackage(bytes memory msgBytes) internal pure returns (TransferInSynPackage memory, bool) {
        TransferInSynPackage memory transInSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) transInSynPkg.amount = iter.next().toUint();
            else if (idx == 1) transInSynPkg.recipient = ((iter.next().toAddress()));
            else if (idx == 2) transInSynPkg.refundAddr = iter.next().toAddress();
            else break;
            idx++;
        }
        return (transInSynPkg, success);
    }

    function _encodeTransferInRefundPackage(TransferInRefundPackage memory transInAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = transInAckPkg.refundAmount.encodeUint();
        elements[1] = transInAckPkg.refundAddr.encodeAddress();
        elements[2] = uint256(transInAckPkg.status).encodeUint();
        return elements.encodeList();
    }

    function _handleTransferInSynPackage(bytes memory msgBytes) internal returns (bytes memory) {
        (TransferInSynPackage memory transInSynPkg, bool success) = _decodeTransferInSynPackage(msgBytes);
        require(success, "unrecognized transferIn package");
        uint32 resCode = _doTransferIn(transInSynPkg);
        if (resCode != TRANSFER_IN_SUCCESS) {
            TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage({
            refundAmount : transInSynPkg.amount,
            refundAddr : transInSynPkg.refundAddr,
            status : resCode
            });
            return _encodeTransferInRefundPackage(transInAckPkg);
        } else {
            return new bytes(0);
        }
    }

    function _doTransferIn(TransferInSynPackage memory transInSynPkg) internal returns (uint32) {
        if (address(this).balance < transInSynPkg.amount) {
            return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
        }
        (bool success,) = transInSynPkg.recipient.call{gas : MAX_GAS_FOR_TRANSFER_BNB, value : transInSynPkg.amount}("");
        if (!success) {
            return TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT;
        }
        emit TransferInSuccess(transInSynPkg.recipient, transInSynPkg.amount);
        return TRANSFER_IN_SUCCESS;
    }

    function _decodeTransferOutAckPackage(bytes memory msgBytes) internal pure returns (TransferOutAckPackage memory, bool) {
        TransferOutAckPackage memory transOutAckPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) transOutAckPkg.refundAmount = iter.next().toUint();
            else if (idx == 1) transOutAckPkg.refundAddr = ((iter.next().toAddress()));
            else if (idx == 2) transOutAckPkg.status = uint32(iter.next().toUint());
            else break;
            idx++;
        }
        return (transOutAckPkg, success);
    }

    function _handleTransferOutAckPackage(bytes memory msgBytes) internal {
        (TransferOutAckPackage memory transOutAckPkg, bool decodeSuccess) = _decodeTransferOutAckPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut ack package");
        _doRefund(transOutAckPkg);
    }

    function _doRefund(TransferOutAckPackage memory transOutAckPkg) internal {
        (bool success,) = transOutAckPkg.refundAddr.call{gas : MAX_GAS_FOR_TRANSFER_BNB, value : transOutAckPkg.refundAmount}("");
        if (!success) {
            emit RefundFailure(transOutAckPkg.refundAddr, transOutAckPkg.refundAmount, transOutAckPkg.status);
        } else {
            emit RefundSuccess(transOutAckPkg.refundAddr, transOutAckPkg.refundAmount, transOutAckPkg.status);
        }
    }

    function _decodeTransferOutSynPackage(bytes memory msgBytes) internal pure returns (TransferOutSynPackage memory, bool) {
        TransferOutSynPackage memory transOutSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) transOutSynPkg.amount = iter.next().toUint();
            else if (idx == 1) transOutSynPkg.recipient = ((iter.next().toAddress()));
            else if (idx == 2) transOutSynPkg.refundAddr = iter.next().toAddress();
            else break;
            idx++;
        }
        return (transOutSynPkg, success);
    }

    function _handleTransferOutFailAckPackage(bytes memory msgBytes) internal {
        (TransferOutSynPackage memory transOutSynPkg, bool decodeSuccess) = _decodeTransferOutSynPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut syn package");
        TransferOutAckPackage memory transOutAckPkg;
        transOutAckPkg.refundAmount = transOutSynPkg.amount;
        transOutAckPkg.refundAddr = transOutSynPkg.refundAddr;
        transOutAckPkg.status = TRANSFER_IN_FAILURE_UNKNOWN;
        _doRefund(transOutAckPkg);
    }

    function _encodeTransferOutSynPackage(TransferOutSynPackage memory transOutSynPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = transOutSynPkg.amount.encodeUint();
        elements[1] = transOutSynPkg.recipient.encodeAddress();
        elements[2] = transOutSynPkg.refundAddr.encodeAddress();
        return elements.encodeList();
    }
}

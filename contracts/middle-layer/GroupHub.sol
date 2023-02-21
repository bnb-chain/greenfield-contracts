// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "../ResourceHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

contract GroupHub is ResourceHub {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- struct -----------------*/
    struct CreateSynPackage {
        address creator;
        string name;
        address[] members;
    }

    /*----------------- external function -----------------*/
    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param name The group's name
     * @param members The initial members of the group
     */
    function createGroup(string calldata name, address[] calldata members) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        CreateSynPackage memory synPkg = CreateSynPackage({creator: msg.sender, name: name, members: members});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNELID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(msg.sender, name, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param name The group's name
     */
    function deleteGroup(string calldata name) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        DeleteSynPackage memory synPkg = DeleteSynPackage({operator: msg.sender, name: name});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNELID, _encodeDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(msg.sender, name, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateSynPackage(CreateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](synPkg.members.length);
        for (uint256 i; i < synPkg.members.length; ++i) {
            members[i] = synPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = members.encodeList();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }
}

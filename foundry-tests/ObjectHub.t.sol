// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/ObjectHub.sol";
import "../contracts/tokens/ERC721NonTransferable.sol";
import "../contracts/lib/RLPDecode.sol";
import "../contracts/lib/RLPEncode.sol";

contract ObjectHubTest is Test, ObjectHub {
    using RLPEncode for *;
    using RLPDecode for *;

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721NonTransferable public objectToken;
    ObjectHub public objectHub;
    GovHub public govHub;

    function setUp() public {
        vm.createSelectFork("test");

        govHub = GovHub(GOV_HUB);
        objectHub = ObjectHub(OBJECT_HUB);
        objectToken = ERC721NonTransferable(objectHub.ERC721Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(OBJECT_HUB, "objectHub");
        vm.label(CROSS_CHAIN, "crossChain");
        vm.label(address(objectToken), "objectToken");
    }

    function testBasicInfo() public {
        string memory baseUri = objectToken.baseURI();
        assertEq(baseUri, "object");
    }

    function testGov() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newObject"),
            targets: abi.encodePacked(address(objectHub))
        });
        bytes memory msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, address(objectHub));
        emit ParamChange("BaseURI", bytes("newObject"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);
    }

    function testMirror(uint256 id) public {
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({id: id, owner: msg.sender});
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(objectToken));
        emit Transfer(address(0), msg.sender, id);
        vm.prank(CROSS_CHAIN);
        objectHub.handleSynPackage(OBJECT_CHANNEL_ID, msgBytes);
    }

    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = bytes(proposal.key).encodeBytes();
        elements[1] = proposal.values.encodeBytes();
        elements[2] = proposal.targets.encodeBytes();
        return elements.encodeList();
    }

    function _encodeMirrorSynPackage(CmnMirrorSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.id.encodeUint();
        elements[1] = synPkg.owner.encodeAddress();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 *
 * forge script script/GenerateProposerProof.s.sol:GenerateProposerProof --rpc-url=$RPC_URL -vvv --ffi
 *
 */
contract GenerateProposerProof is Script {
    address beaconRootsContract = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02; // same on holesky and mainnet
    uint256 private constant HISTORY_BUFFER_LENGTH = 8191;
    uint256 GENESIS_BLOCK_TIMESTAMP;

    function setUp() public {
        if (block.chainid == 17000) {
            // Holesky
            GENESIS_BLOCK_TIMESTAMP = 1695902400;
        } else if (block.chainid == 1) {
            // Mainnet
            GENESIS_BLOCK_TIMESTAMP = 1606824023;
        }
    }

    function run() public {
        uint256 slot = _timeStampToSlot(block.timestamp) - 10; // get a recent slot
        // uint256 slot = vm.promptUint("Enter slot number");

        require(slot > 0, "slot must be greater than 0");

        // Ensure slot is within the last 8191 slots
        uint256 curSlot = _timeStampToSlot(block.timestamp);
        require(curSlot - slot < HISTORY_BUFFER_LENGTH, "slot must be within 8191 slots of current slot");

        // Fetch beacon block header from beacon node
        string memory beaconBlockHeaderJSON = string(_getBlockHeader(slot));
        console.log(beaconBlockHeaderJSON);

        // Parse beacon block header JSON
        bytes32 blockRoot = vm.parseJsonBytes32(
            beaconBlockHeaderJSON,
            ".block_root"
        );
        bytes32 bodyRoot = vm.parseJsonBytes32(
            beaconBlockHeaderJSON,
            ".body_root"
        );
        bytes32 parentRoot = vm.parseJsonBytes32(
            beaconBlockHeaderJSON,
            ".parent_root"
        );
        bytes32 stateRoot = vm.parseJsonBytes32(
            beaconBlockHeaderJSON,
            ".state_root"
        );
        uint256 proposerIndex = vm.parseJsonUint(
            beaconBlockHeaderJSON,
            ".proposer_index"
        );
        uint256 slotFromBeaconNode = vm.parseJsonUint(
            beaconBlockHeaderJSON,
            ".slot"
        );
        console.logBytes32(blockRoot);
        console.logBytes32(bodyRoot);
        console.logBytes32(parentRoot);
        console.logBytes32(stateRoot);
        console.logUint(proposerIndex);

        bytes32[2] memory proof = buildBeaconBlockProof(
            parentRoot,
            stateRoot,
            bodyRoot
        );

        bool valid = verifyProposerAt(slotFromBeaconNode, proposerIndex, proof);
        require(valid, "Proof is invalid, wrong proposer index for this slot");
    }

    function buildBeaconBlockProof(
        bytes32 parentRoot,
        bytes32 stateRoot,
        bytes32 bodyRoot
    ) public pure returns (bytes32[2] memory) {
        bytes32 parentAndStateNode = sha256(
            abi.encodePacked(parentRoot, stateRoot)
        );
        bytes32 bodyAndZeroes = sha256(abi.encodePacked(bodyRoot, bytes32(0)));
        
        // sha256(abi.encodePacked(bytes32(0), bytes32(0)));
        bytes32 zeroesLeaf = hex"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b";
        bytes32 rightNode = sha256(abi.encodePacked(bodyAndZeroes, zeroesLeaf));
        return [parentAndStateNode, rightNode];
    }

    function verifyProposerAt(
        uint256 slot,
        uint256 proposerIndex,
        bytes32[2] memory proof
    ) public returns (bool) {
        // Returns the parent_root, so check the next slot of the target block
        (bool success, bytes32 beaconRootFromChain) = _getRootFromSlot(slot + 1);
        assert(success);

        bytes32 slotAndProposerIndexNode = sha256(
            abi.encodePacked(
                abi.encodePacked(
                    _to_little_endian_64(uint64(slot)),
                    bytes24(0)
                ),
                abi.encodePacked(
                    _to_little_endian_64(uint64(proposerIndex)),
                    bytes24(0)
                )
            )
        );

        bytes32 leftNode = sha256(
            abi.encodePacked(slotAndProposerIndexNode, proof[0])
        );
        bytes32 root = sha256(abi.encodePacked(leftNode, proof[1]));
        console.logBytes32(root);

        // Verify computed and expected deposit data roots match
        return root == beaconRootFromChain;
    }

    // same way to do it all in 1 function call
    function verifyProposerAt2(
        uint256 slot,
        uint256 proposerIndex,
        bytes32 parentRoot,
        bytes32 stateRoot,
        bytes32 bodyRoot
    ) public returns (bool) {
        // Returns the parent_root, so check the next slot of the target block
        (bool success, bytes32 beaconRootFromChain) = _getRootFromSlot(slot + 1);
        assert(success);
        console.logBytes32(beaconRootFromChain);

        bytes32 slotAndProposerIndexNode = sha256(
            abi.encodePacked(
                abi.encodePacked(
                    _to_little_endian_64(uint64(slot)),
                    bytes24(0)
                ),
                abi.encodePacked(
                    _to_little_endian_64(uint64(proposerIndex)),
                    bytes24(0)
                )
            )
        );

        bytes32 parentAndStateNode = sha256(
            abi.encodePacked(parentRoot, stateRoot)
        );

        bytes32 bodyAndZeroes = sha256(abi.encodePacked(bodyRoot, bytes32(0)));

        bytes32 zeroesLeaf = hex"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b";
        bytes32 leftNode = sha256(
            abi.encodePacked(slotAndProposerIndexNode, parentAndStateNode)
        );
        bytes32 rightNode = sha256(abi.encodePacked(bodyAndZeroes, zeroesLeaf));
        bytes32 root = sha256(abi.encodePacked(leftNode, rightNode));
        console.logBytes32(root);

        // Verify computed and expected deposit data roots match
        return root == beaconRootFromChain;
    }

    function _getBlockHeader(uint256 slot) internal returns (bytes memory) {
        string[] memory inputs = new string[](2);
        inputs[0] = "./shell-scripts/getBlockHeader.sh";
        inputs[1] = vm.toString(slot);
        return vm.ffi(inputs);
    }

    function _getRootFromSlot(uint256 slot) public returns (bool, bytes32) {
        uint256 timestamp = _slotToTimestamp(slot);
        return _getRootFromTimestamp(timestamp);
    }

    function _getRootFromTimestamp(
        uint256 timestamp
    ) public returns (bool, bytes32) {
        (bool ret, bytes memory data) = beaconRootsContract.call(
            bytes.concat(bytes32(timestamp))
        );
        return (ret, bytes32(data));
    }

    function _slotToTimestamp(uint256 slot) public view returns (uint256) {
        return slot * 12 + GENESIS_BLOCK_TIMESTAMP;
    }

    function _timeStampToSlot(uint256 timestamp) public view returns (uint256) {
        return (timestamp - GENESIS_BLOCK_TIMESTAMP) / 12;
    }

    function _to_little_endian_64(
        uint64 value
    ) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        // Byteswapping during copying to bytes.
        ret[0] = bytesValue[7];
        ret[1] = bytesValue[6];
        ret[2] = bytesValue[5];
        ret[3] = bytesValue[4];
        ret[4] = bytesValue[3];
        ret[5] = bytesValue[2];
        ret[6] = bytesValue[1];
        ret[7] = bytesValue[0];
    }
}

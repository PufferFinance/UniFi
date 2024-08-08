// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

library BeaconChainHelperLib {
    address internal constant _BEACON_ROOT_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    function verifyProposerAt(uint256 timestamp, uint256 proposerIndex, bytes32[2] memory proof)
        internal
        returns (bool)
    {
        // Returns the parent_root, so check the next slot of the target block
        (bool success, bytes32 beaconRootFromChain) = getRootFromTimestamp(timestamp + 12);
        assert(success);

        uint256 slot = timeStampToSlot(timestamp);

        bytes32 slotAndProposerIndexNode = sha256(
            abi.encodePacked(
                abi.encodePacked(to_little_endian_64(uint64(slot)), bytes24(0)),
                abi.encodePacked(to_little_endian_64(uint64(proposerIndex)), bytes24(0))
            )
        );

        bytes32 leftNode = sha256(abi.encodePacked(slotAndProposerIndexNode, proof[0]));
        bytes32 root = sha256(abi.encodePacked(leftNode, proof[1]));

        // Verify computed and expected beacon block roots match
        return root == beaconRootFromChain;
    }

    function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret) {
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

    function getRootFromTimestamp(uint256 timestamp) internal returns (bool, bytes32) {
        (bool ret, bytes memory data) = _BEACON_ROOT_CONTRACT.call(bytes.concat(bytes32(timestamp)));
        return (ret, bytes32(data));
    }

    function timeStampToSlot(uint256 timestamp) internal view returns (uint256) {
        uint256 genesisBlockTimestamp;

        // TODO modify for mainnet
        if (block.chainid == 17000) {
            // Holesky
            genesisBlockTimestamp = 1695902400;
        } else if (block.chainid == 1) {
            // Mainnet
            genesisBlockTimestamp = 1606824023;
        } else if (block.chainid == 7014190335) {
            // Helder
            genesisBlockTimestamp = 1718967660;
        }

        return ((timestamp - genesisBlockTimestamp) / 12);
    }
}

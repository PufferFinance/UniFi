// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract UnifiContract {

    struct BlockHeader {
        uint256 unifiChainId;
        uint256 sequenceNum;
        uint256 gasLimit;
        bytes32 unifiBlockHash;
    }

    uint256 public genesisBlockNumber;

    mapping(uint256 => uint256) public lastRollupSubmissionBlock;
    mapping(uint256 => uint256) public lastSequenceNum;

    error OneRollupSubmissionPerBlock();
    error NonMonotonicSequenceNum(uint256 expected);

    event BlockSubmitted(
        uint256 indexed unifiChainId,
        uint256 gasLimit,
        bytes32 unifiBlockHash
    );

    constructor() {
        genesisBlockNumber = block.number;
    }

    function submitBlock(
        BlockHeader memory header,
        bytes calldata
    ) external {
        // assert that the sequence number is valid and increment it
        uint256 _sequenceNum = lastSequenceNum[header.unifiChainId]++;
        if (_sequenceNum != header.sequenceNum) revert NonMonotonicSequenceNum(_sequenceNum);
        // assert this is the first rollup block submitted for this host block
        if (lastRollupSubmissionBlock[header.unifiChainId] == block.number)
            revert OneRollupSubmissionPerBlock();
        lastRollupSubmissionBlock[header.unifiChainId] = block.number;

        // emit event
        emit BlockSubmitted(
            header.unifiChainId,
            header.gasLimit,
            header.unifiBlockHash
        );
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;
/**
 * @title IPufferBatchInbox
 * @dev Interface for the PufferBatchInbox contract.
 */
interface IPufferBatchInbox {
    /// @dev Error for incorrect bond amount.
    error IncorrectBondAmount();

    /// @dev Error for non-existent batch.
    error BatchDoesNotExist();

    /// @dev Error for already dispersed bond.
    error BondAlreadyDispersed();

    /// @dev Error for non-allowlisted validator.
    error NotAllowlisted();

    /// @dev Error for invalid proof.
    error InvalidProof();

    /// @dev Error for existent batch.
    error BatchAlreadyExist();

    /**
     * @notice Allowlist a set of validators.
     * @param indexes The indexes of the validators to allowlist.
     */
    function allowlistValidators(uint256[] calldata indexes) external;

    /**
     * @notice Publish a batch.
     */
    function publishBatch() external payable;

    /**
     * @notice Return bond to the sender.
     * @param timestamp The timestamp of the batch.
     * @param sender The sender of the batch.
     * @param proposerIndex The index of the proposer.
     * @param proof The proof for verification.
     */
    function returnBond(uint256 timestamp, address sender, uint256 proposerIndex, bytes32[2] memory proof) external;

    /**
     * @notice Distribute bond between the sender and protocol.
     * @param timestamp The timestamp of the batch.
     * @param sender The sender of the batch.
     * @param proposerIndex The index of the proposer.
     * @param proof The proof for verification.
     */
    function distributeBond(uint256 timestamp, address sender, uint256 proposerIndex, bytes32[2] memory proof)
        external;
}

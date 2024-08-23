// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title OperatorData
 * @notice Struct to store information about an operator in the UniFi AVS system.
 * @dev This struct is used to keep track of important operator details.
 */
struct OperatorCommitment {
    /// @notice The delegate key for the operator.
    bytes delegateKey;
    /// @notice Bitmap of chain IDs the operator is committed to.
    uint256 chainIDBitMap;
}

struct OperatorData {
    /// @notice The number of validators associated with this operator.
    uint128 validatorCount;
    /// @notice The current commitment of the operator.
    OperatorCommitment commitment;
    /// @notice The block number when the operator started the deregistration process.
    uint256 startOperatorDeregisterBlock;
    /// @notice The pending commitment of the operator.
    OperatorCommitment pendingCommitment;
    /// @notice The block number after which the pending commitment becomes valid.
    uint256 commitmentValidAfter;
}

/**
 * @title OperatorDataExtended
 * @notice Struct to store extended information about an operator in the UniFi AVS system.
 * @dev This struct combines OperatorData with additional status information.
 */
struct OperatorDataExtended {
    /// @notice The number of validators associated with this operator.
    uint128 validatorCount;
    /// @notice The current commitment of the operator.
    OperatorCommitment commitment;
    /// @notice The block number when the operator started the deregistration process.
    uint256 startOperatorDeregisterBlock;
    /// @notice Whether the operator is registered or not.
    bool isRegistered;
    /// @notice The pending commitment of the operator.
    OperatorCommitment pendingCommitment;
    /// @notice The block number after which the pending commitment becomes valid.
    uint256 commitmentValidAfter;
    /// @notice The active commitment of the operator.
    OperatorCommitment activeCommitment;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPod.sol";

/**
 * @title ValidatorData
 * @notice Struct to store information about a validator in the UniFi AVS system.
 * @dev This struct is used to keep track of important validator details.
 */
struct ValidatorData {
    /// @notice The address of the EigenPod associated with this validator.
    address eigenPod;
    /// @notice The beacon chain validator index.
    uint64 index;
    /// @notice The address of the operator managing this validator.
    address operator;
    /// @notice The block number until which the validator is registered.
    uint64 registeredUntil;
}

/**
 * @title ValidatorDataExtended
 * @notice Struct to store comprehensive information about a validator.
 * @dev This struct combines ValidatorData with additional status information.
 */
struct ValidatorDataExtended {
    address eigenPod;
    /// @notice The index of the validator in the beacon chain.
    uint64 validatorIndex;
    /// @notice The current status of the validator in the EigenPod.
    IEigenPod.VALIDATOR_STATUS status;
    /// @notice Indicates whether the validator's EigenPod is delegated to the operator.
    bool backedByStake;
    /// @notice The address of the operator managing this validator.
    address operator;
    /// @notice The delegate key associated with the validator's operator.
    bytes delegateKey;
    /// @notice The block number until which the validator is registered.
    uint64 registeredUntil;
    /// @notice Indicates whether the validator is currently registered (current block < registeredUntil).
    bool registered;
    /// @notice The active commitment of the operator.
    OperatorCommitment activeCommitment;
}

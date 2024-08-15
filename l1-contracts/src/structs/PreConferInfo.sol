// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./ValidatorData.sol";
import "eigenlayer/interfaces/IEigenPod.sol";

/**
 * @title PreConferInfo
 * @notice Struct to store comprehensive information about a validator before conferring.
 * @dev This struct combines ValidatorData with additional status information.
 */
struct PreConferInfo {
    /// @notice The core data of the validator.
    ValidatorData data;
    /// @notice The index of the validator in the beacon chain.
    uint64 validatorIndex;
    /// @notice The current status of the validator in the EigenPod.
    IEigenPod.VALIDATOR_STATUS status;
    /// @notice Indicates whether the validator is backed by staked ETH.
    bool backedByStake;
    /// @notice The delegate key associated with the validator's operator.
    bytes delegateKey;
}

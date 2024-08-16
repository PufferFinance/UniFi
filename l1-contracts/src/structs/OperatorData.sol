// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title OperatorData
 * @notice Struct to store information about an operator in the UniFi AVS system.
 * @dev This struct is used to keep track of important operator details.
 */
struct OperatorData {
    /// @notice The number of validators associated with this operator.
    uint128 validatorCount;
    /// @notice The delegate key for the operator.
    bytes delegateKey;
}

/**
 * @title OperatorDataExtended
 * @notice Struct to store extended information about an operator in the UniFi AVS system.
 * @dev This struct combines OperatorData with additional status information.
 */
struct OperatorDataExtended {
    /// @notice The number of validators associated with this operator.
    uint128 validatorCount;
    /// @notice The delegate key for the operator.
    bytes delegateKey;
    bool isRegistered;
}

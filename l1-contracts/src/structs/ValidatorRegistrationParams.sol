// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

/**
 * @title ValidatorRegistrationParams
 * @notice Struct to store parameters for validator registration in the UniFi AVS system.
 * @dev This struct is used when registering a new validator.
 */
struct ValidatorRegistrationParams {
    /// @notice The registration signature in G1 point format.
    BN254.G1Point registrationSignature;
    /// @notice The validator's public key in G1 point format.
    BN254.G1Point pubkeyG1;
    /// @notice The validator's public key in G2 point format.
    BN254.G2Point pubkeyG2;
    /// @notice The delegate public key for the validator.
    bytes delegatePubKey;
    /// @notice A unique salt for the registration.
    bytes32 salt;
    /// @notice The expiry timestamp for the registration.
    uint256 expiry;
}

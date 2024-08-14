// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

struct ValidatorRegistrationParams {
    BN254.G1Point registrationSignature;
    BN254.G1Point pubkeyG1;
    BN254.G2Point pubkeyG2;
    bytes32 ecdsaPubKeyHash;
    bytes32 salt;
    uint256 expiry;
}

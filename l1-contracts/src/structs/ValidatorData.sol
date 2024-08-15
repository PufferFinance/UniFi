// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

struct ValidatorData {
    address eigenPod;
    uint256 validatorIndex;
    bytes delegatePubKey;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

struct OperatorData {
    address operatorContract;
    bool isRegistered;
    bool isDelegated;
    uint256 validatorCount;
}

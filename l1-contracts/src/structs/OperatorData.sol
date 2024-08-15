// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

struct OperatorData {
    address operatorAddress;
    bool isRegistered;
    mapping(address => bool) delegatedPodOwners;
    uint256 validatorCount;
}

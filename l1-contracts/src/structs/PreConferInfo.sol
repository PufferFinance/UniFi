// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./ValidatorData.sol";
import "eigenlayer/interfaces/IEigenPod.sol";

struct PreConferInfo {
    ValidatorData data;
    uint64 validatorIndex;
    IEigenPod.VALIDATOR_STATUS status;
    bool backedByStake;
    bytes delegateKey;
}

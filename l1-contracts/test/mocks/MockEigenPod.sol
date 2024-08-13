// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPod.sol";

contract MockEigenPod is IEigenPod {
    mapping(bytes32 => VALIDATOR_STATUS) public validatorStatuses;

    function setValidatorStatus(bytes32 pubkeyHash, VALIDATOR_STATUS status) external {
        validatorStatuses[pubkeyHash] = status;
    }

    function validatorStatus(bytes32 pubkeyHash) external view returns (VALIDATOR_STATUS) {
        return validatorStatuses[pubkeyHash];
    }

    // Implement other functions from IEigenPod as needed for testing
}

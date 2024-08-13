// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPodManager.sol";
import "eigenlayer/interfaces/IEigenPod.sol";

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPodManager.sol";
import "eigenlayer/interfaces/IEigenPod.sol";

contract MockEigenPodManager {
    mapping(address => IEigenPod) public pods;

    function hasPod(address podOwner) external view returns (bool) {
        return address(pods[podOwner]) != address(0);
    }

    function getPod(address podOwner) external view returns (IEigenPod) {
        return pods[podOwner];
    }

    // Mock function to set a pod for testing
    function setPod(address podOwner, IEigenPod pod) external {
        pods[podOwner] = pod;
    }

    // Implement other functions from IEigenPodManager as needed for testing
}

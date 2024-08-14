// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPodManager.sol";
import "./MockEigenPod.sol";

contract MockEigenPodManager {
    mapping(address => MockEigenPod) public pods;

    function hasPod(address podOwner) external view returns (bool) {
        return address(pods[podOwner]) != address(0);
    }

    function getPod(address podOwner) external view returns (IEigenPod) {
        return pods[podOwner];
    }

    // Mock function to create a new pod for testing
    function createPod(address podOwner) external returns (MockEigenPod) {
        MockEigenPod newPod = new MockEigenPod(podOwner);
        pods[podOwner] = newPod;
        return newPod;
    }

    // Mock function to set validator status for a pod
    function setValidatorStatus(address podOwner, bytes32 pubkeyHash, IEigenPod.VALIDATOR_STATUS status) external {
        require(address(pods[podOwner]) != address(0), "Pod does not exist");
        pods[podOwner].setValidatorStatus(pubkeyHash, status);
    }

    // Remove the setPod function as it's no longer needed

    // Implement other functions from IEigenPodManager as needed for testing
}

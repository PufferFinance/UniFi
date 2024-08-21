// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { UniFiAVSManager } from "../src/UniFiAVSManager.sol";
import "../test/mocks/MockEigenPodManager.sol";
import "../test/mocks/MockDelegationManager.sol";
import "../test/mocks/MockAVSDirectory.sol";

// to run the script: forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "createEigenPod(address)" "0xabcdefg..."

contract UniFiAVSScripts is Script {
    MockDelegationManager mockDelegationManager;
    MockEigenPodManager mockEigenPodManager;
    UniFiAVSManager uniFiAVSManager;

    // update the addresses to the deployed ones
    address mockDelegationManagerAddress = address(123);
    address mockEigenPodManagerAddress = address(123);
    address uniFiAVSManagerAddress = address(123);

    function setUp() public {
        // Initialize the contract instances with their deployed addresses
        mockDelegationManager = MockDelegationManager(mockDelegationManagerAddress);
        mockEigenPodManager = MockEigenPodManager(mockEigenPodManagerAddress);
        uniFiAVSManager = UniFiAVSManager(uniFiAVSManagerAddress);
    }

    // Action 1: Create a Mock Pod
    function createEigenPod(address podOwner) public {
        vm.startBroadcast();
        mockEigenPodManager.createPod(podOwner);
        vm.stopBroadcast();
    }

    // Action 2: Add Validators to MockEigenPod
    function addValidatorsToEigenPod(
        address podOwner,
        bytes32[] memory pubkeyHashes,
        MockEigenPod.ValidatorInfo[] memory validators
    ) public {
        vm.startBroadcast();
        for (uint256 i = 0; i < validators.length; i++) {
            mockEigenPodManager.setValidator(podOwner, pubkeyHashes[i], validators[i]);
        }
        vm.stopBroadcast();
    }

    // Action 3: Register Validators with UniFiAVSManager
    function registerValidatorsToUniFiAVS(address podOwner, bytes32[] memory blsPubKeyHashes) public {
        vm.startBroadcast();
        uniFiAVSManager.registerValidators(podOwner, blsPubKeyHashes);
        vm.stopBroadcast();
    }

    // Action 4: Register an Operator with UniFiAVSManager (the caller of this script should be the operator)
    function registerOperatorToUniFiAVS(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) public {
        vm.startBroadcast();
        uniFiAVSManager.registerOperator(operatorSignature);
        vm.stopBroadcast();
    }

    // Action 5: Delegate from PodOwner to Operator using MockDelegationManager
    function delegateFromPodOwner(address podOwner, address operator) public {
        vm.startBroadcast();
        mockDelegationManager.setDelegation(podOwner, operator);
        vm.stopBroadcast();
    }

    // Action 6: Set the Operator's Delegate Key
    function setOperatorDelegateKey(bytes memory newDelegateKey) public {
        vm.startBroadcast();
        uniFiAVSManager.setOperatorDelegateKey(newDelegateKey);
        vm.stopBroadcast();
    }
}

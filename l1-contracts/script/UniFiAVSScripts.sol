// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { UniFiAVSManager } from "../src/UniFiAVSManager.sol";
import "../src/structs/ValidatorData.sol";
import "../src/structs/OperatorData.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import "../test/mocks/MockEigenPodManager.sol";
import "../test/mocks/MockDelegationManager.sol";
import "../test/mocks/MockAVSDirectory.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IEigenPod } from "eigenlayer/interfaces/IEigenPod.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";

// to run the script: forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "createEigenPod(address)" "0xabcdefg..."

contract UniFiAVSScripts is Script {
    using Strings for uint256;

    // DO NOT CHANGE THE ORDER OF THE STRUCTS BELOW
    // Struct for Validator information
    struct Validator {
        string effective_balance;
        string activation_eligibility_epoch;
        string activation_epoch;
        string exit_epoch;
        bytes pubkey;
        bool slashed;
        string withdrawable_epoch;
        bytes32 withdrawal_credentials;
    }

    // Struct for Data containing validator details
    struct ValidatorData {
        string index;
        Validator validator;
    }

    // Struct for the main object containing execution status, finalized status, and an array of Data
    struct BeaconValidatorData {
        ValidatorData[] data;
        bool execution_optimistic;
        bool finalized;
    }

    MockDelegationManager mockDelegationManager;
    MockEigenPodManager mockEigenPodManager;
    UniFiAVSManager uniFiAVSManager;

    // update the addresses to the deployed ones
    address mockDelegationManagerAddress = address(0x239eD3B6B4bd3a1cCaDB79d2A8c4862BB2324D89);
    address mockEigenPodManagerAddress = address(0x27065dA1e634119b5f50167A650B7109B8965350);
    address uniFiAVSManagerAddress = address(0x5CcEa336064524a3D7d636e33BFd53f2917F27A0);
    address avsDirectoryAddress = address(0x5d0F57C63Bd70843dc600A6da78fEcC7c390Cb34);

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

    function registerValidatorsToUniFiAVS(address podOwner, bytes[] memory pubkeys) public {
        vm.startBroadcast();
        bytes32[] memory pubkeyHashes = new bytes32[](pubkeys.length);
        for (uint256 i = 0; i < pubkeys.length; i++) {
            pubkeyHashes[i] = keccak256(pubkeys[i]);
        }
        uniFiAVSManager.registerValidators(podOwner, pubkeyHashes);
        vm.stopBroadcast();
    }

    // Action 4: Register an Operator with UniFiAVSManager and set initial commitment (the caller of this script should be the operator)
    function registerOperatorToUniFiAVS(uint256 signerPk, OperatorCommitment memory initialCommitment) public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        vm.startBroadcast();
        (, operatorSignature) = _getOperatorSignature(
            signerPk,
            msg.sender,
            uniFiAVSManagerAddress,
            bytes32(keccak256(abi.encodePacked(block.timestamp, msg.sender))),
            type(uint256).max
        );
        uniFiAVSManager.registerOperator(operatorSignature);
        uniFiAVSManager.setOperatorCommitment(initialCommitment);
        vm.stopBroadcast();
    }

    // Action 5: Delegate from PodOwner to Operator using MockDelegationManager
    function delegateFromPodOwner(address podOwner, address operator) public {
        vm.startBroadcast();
        mockDelegationManager.setOperator(operator, true);
        mockDelegationManager.setDelegation(podOwner, operator);
        vm.stopBroadcast();
    }

    // Action 6: Set the Operator's Commitment
    function setOperatorCommitment(OperatorCommitment memory newCommitment) public {
        vm.startBroadcast();
        uniFiAVSManager.setOperatorCommitment(newCommitment);
        vm.stopBroadcast();
    }

    // Action 7: Update Operator's Commitment
    function updateOperatorCommitment() public {
        vm.startBroadcast();
        uniFiAVSManager.updateOperatorCommitment();
        vm.stopBroadcast();
    }

    // Action 8: Start Deregistering an Operator
    function startDeregisterOperator() public {
        vm.startBroadcast();
        uniFiAVSManager.startDeregisterOperator();
        vm.stopBroadcast();
    }

    // Action 9: Finish Deregistering an Operator
    function finishDeregisterOperator() public {
        vm.startBroadcast();
        uniFiAVSManager.finishDeregisterOperator();
        vm.stopBroadcast();
    }

    // Action 10: Complete Pod Setup and Validator Registration
    function setupPodAndRegisterValidatorsFromJsonFile(
        uint256 signerPk,
        address podOwner,
        OperatorCommitment memory initialCommitment,
        string memory filePath
    ) public {
        vm.startBroadcast();
        // Step 1: Create a Mock Pod
        createEigenPod(podOwner);

        // Step 2: Delegate from PodOwner to Operator
        delegateFromPodOwner(podOwner, msg.sender);

        // Step 3: Register the Operator
        registerOperatorToUniFiAVS(signerPk, initialCommitment);

        // Step 3: Add validators to pod and register them to the AVS
        addValidatorsFromJsonFile(filePath, podOwner);
    }

    function addValidatorsFromJsonFile(string memory filePath, address podOwner) public {
        // Read the JSON file as a string
        string memory jsonData = vm.readFile(filePath);
        bytes memory data = vm.parseJson(jsonData);
        BeaconValidatorData memory beaconData = abi.decode(data, (BeaconValidatorData));

        bytes32[] memory pubkeyHashes = new bytes32[](beaconData.data.length);
        IEigenPod.ValidatorInfo[] memory validators = new IEigenPod.ValidatorInfo[](beaconData.data.length);

        // Iterate over the array and extract the required fields
        for (uint256 i = 0; i < beaconData.data.length; i++) {
            // Extract index and pubkey from each object
            ValidatorData memory validatorData = beaconData.data[i];
            uint256 index = stringToUint(validatorData.index);

            pubkeyHashes[i] = keccak256(validatorData.validator.pubkey);
            validators[i] = IEigenPod.ValidatorInfo({
                validatorIndex: uint64(index),
                restakedBalanceGwei: 0,
                mostRecentBalanceUpdateTimestamp: 0,
                status: IEigenPod.VALIDATOR_STATUS.ACTIVE
            });

            mockEigenPodManager.setValidator(podOwner, pubkeyHashes[i], validators[i]);

            console.log("Added validator with index:", index);
        }

        uniFiAVSManager.registerValidators(podOwner, pubkeyHashes);
    }

    function addValidatorsDirectly(address podOwner, bytes[] memory pubkeys, uint64[] memory validatorIndices) public {
        require(pubkeys.length == validatorIndices.length, "Mismatched array lengths");

        bytes32[] memory pubkeyHashes = new bytes32[](pubkeys.length);
        IEigenPod.ValidatorInfo[] memory validators = new IEigenPod.ValidatorInfo[](pubkeys.length);

        for (uint256 i = 0; i < pubkeys.length; i++) {
            pubkeyHashes[i] = keccak256(pubkeys[i]);
            validators[i] = IEigenPod.ValidatorInfo({
                validatorIndex: validatorIndices[i],
                restakedBalanceGwei: 0,
                mostRecentBalanceUpdateTimestamp: 0,
                status: IEigenPod.VALIDATOR_STATUS.ACTIVE
            });

            mockEigenPodManager.setValidator(podOwner, pubkeyHashes[i], validators[i]);

            console.log("Added validator with index:", validatorIndices[i]);
        }

        uniFiAVSManager.registerValidators(podOwner, pubkeyHashes);
    }

    function setupPodAndRegisterValidatorsDirectly(
        uint256 signerPk,
        address podOwner,
        OperatorCommitment memory initialCommitment,
        bytes[] memory pubkeys,
        uint64[] memory validatorIndices
    ) public {
        vm.startBroadcast();
        // Step 1: Create a Mock Pod
        createEigenPod(podOwner);

        // Step 2: Delegate from PodOwner to Operator
        delegateFromPodOwner(podOwner, msg.sender);

        // Step 3: Register the Operator
        registerOperatorToUniFiAVS(signerPk, initialCommitment);

        // Step 4: Add validators to pod and register them to the AVS
        addValidatorsDirectly(podOwner, pubkeys, validatorIndices);
        vm.stopBroadcast();
    }

    function _getOperatorSignature(
        uint256 _operatorPrivateKey,
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    ) internal view returns (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        operatorSignature.expiry = expiry;
        operatorSignature.salt = salt;
        {
            digestHash = IAVSDirectory(avsDirectoryAddress).calculateOperatorAVSRegistrationDigestHash(
                operator, avs, salt, expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_operatorPrivateKey, digestHash);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        return (digestHash, operatorSignature);
    }

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            // Check if the character is a digit (0-9)
            require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid character in string");
            result = result * 10 + (uint256(uint8(b[i])) - 48);
        }
        return result;
    }
}

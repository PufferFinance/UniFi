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
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { IEigenPodManager } from "eigenlayer/interfaces/IEigenPodManager.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IEigenPod } from "eigenlayer/interfaces/IEigenPod.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { IEigenPodManager } from "eigenlayer/interfaces/IEigenPodManager.sol";

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

    // Set chainIDBitMap with only index 1 as true (2 in binary is 10, which sets the second bit to 1)
    uint256 constant DEFAULT_CHAIN_BITMAP = 2;

    IDelegationManager delegationManager;
    IEigenPodManager eigenPodManager;
    IAVSDirectory avsDirectory;
    UniFiAVSManager uniFiAVSManager;

    // update the addresses to the deployed ones
    address delegationManagerAddress;
    address eigenPodManagerAddress;
    address uniFiAVSManagerAddress;
    address avsDirectoryAddress;

    bool isHelderChain;

    function setUp() public {
        // Determine which chain we're on and set the appropriate addresses
        if (block.chainid == 7014190335) { // chain ID for Helder
            isHelderChain = true;
            delegationManagerAddress = address(0x239eD3B6B4bd3a1cCaDB79d2A8c4862BB2324D89);
            eigenPodManagerAddress = address(0x27065dA1e634119b5f50167A650B7109B8965350);
            uniFiAVSManagerAddress = address(0x5CcEa336064524a3D7d636e33BFd53f2917F27A0);
            avsDirectoryAddress = address(0x5d0F57C63Bd70843dc600A6da78fEcC7c390Cb34);
        } else {
            isHelderChain = false;
            // Set the addresses for Holesky or Mainnet
            delegationManagerAddress = address(0x...); // Replace with actual address
            eigenPodManagerAddress = address(0x...); // Replace with actual address
            uniFiAVSManagerAddress = address(0x...); // Replace with actual address
            avsDirectoryAddress = address(0x...); // Replace with actual address
        }

        // Initialize the contract instances with their deployed addresses
        if (isHelderChain) {
            delegationManager = IDelegationManager(delegationManagerAddress);
            eigenPodManager = IEigenPodManager(eigenPodManagerAddress);
        } else {
            delegationManager = IDelegationManager(delegationManagerAddress);
            eigenPodManager = IEigenPodManager(eigenPodManagerAddress);
        }
        uniFiAVSManager = UniFiAVSManager(uniFiAVSManagerAddress);
        avsDirectory = IAVSDirectory(avsDirectoryAddress);
    }

    // Helder-only functions

    /// @notice Creates a mock EigenPod for the specified podOwner (Helder only)
    /// @param podOwner The address of the pod owner
    function createEigenPod(address podOwner) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        MockEigenPodManager(address(eigenPodManager)).createPod(podOwner);
        vm.stopBroadcast();
    }

    /// @notice Adds validators to the MockEigenPod for the specified podOwner (Helder only)
    /// @param podOwner The address of the pod owner
    /// @param pubkeyHashes The hashes of the validator public keys
    /// @param validators The validator information
    function addValidatorsToEigenPod(
        address podOwner,
        bytes32[] memory pubkeyHashes,
        IEigenPod.ValidatorInfo[] memory validators
    ) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        for (uint256 i = 0; i < validators.length; i++) {
            MockEigenPodManager(address(eigenPodManager)).setValidator(podOwner, pubkeyHashes[i], validators[i]);
        }
        vm.stopBroadcast();
    }

    /// @notice Delegates from PodOwner to Operator using MockDelegationManager (Helder only)
    /// @param podOwner The address of the pod owner
    /// @param operator The address of the operator
    function delegateFromPodOwner(address podOwner, address operator) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        MockDelegationManager(address(delegationManager)).setOperator(operator, true);
        MockDelegationManager(address(delegationManager)).setDelegation(podOwner, operator);
        vm.stopBroadcast();
    }

    /// @notice Delegates from PodOwner to Operator with signature (Helder only)
    /// @param podOwner The address of the pod owner
    /// @param operator The address of the operator
    /// @param approverSignatureAndExpiry The approver's signature and expiry
    /// @param approverSalt The approver's salt
    function delegateFromPodOwner(
        address podOwner,
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        delegationManager.delegateTo(operator, approverSignatureAndExpiry, approverSalt);
        vm.stopBroadcast();
    }

    /// @notice Adds validators from a JSON file and registers them with UniFiAVSManager (Helder only)
    /// @param filePath The path to the JSON file containing validator data
    /// @param podOwner The address of the pod owner
    function addValidatorsFromJsonFile(string memory filePath, address podOwner) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
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

    /// @notice Adds validators directly to EigenPod and registers them with UniFiAVSManager (Helder only)
    /// @param podOwner The address of the pod owner
    /// @param pubkeys The public keys of the validators
    /// @param validatorIndices The indices of the validators
    function addValidatorsToEigenPodAndRegisterToAVS(
        address podOwner,
        bytes[] memory pubkeys,
        uint64[] memory validatorIndices
    ) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
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

    /// @notice Sets up a pod and registers validators from a JSON file (Helder only)
    /// @param signerPk The private key of the signer
    /// @param podOwner The address of the pod owner
    /// @param initialCommitment The initial commitment for the operator
    /// @param filePath The path to the JSON file containing validator data
    function setupPodAndRegisterValidatorsFromJsonFile(
        uint256 signerPk,
        address podOwner,
        OperatorCommitment memory initialCommitment,
        string memory filePath
    ) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        // Step 1: Create a Mock Pod
        createEigenPod(podOwner);

        // Step 2: Delegate from PodOwner to Operator
        delegateFromPodOwner(podOwner, msg.sender);

        // Step 3: Register the Operator
        registerOperatorToUniFiAVS(signerPk, initialCommitment);

        // Step 4: Add validators to pod and register them to the AVS
        addValidatorsFromJsonFile(filePath, podOwner);
        vm.stopBroadcast();
    }

    /// @notice Sets up a pod and registers validators directly (Helder only)
    /// @param signerPk The private key of the signer
    /// @param podOwner The address of the pod owner
    /// @param initialCommitment The initial commitment for the operator
    /// @param pubkeys The public keys of the validators
    /// @param validatorIndices The indices of the validators
    function setupPodAndRegisterValidators(
        uint256 signerPk,
        address podOwner,
        OperatorCommitment memory initialCommitment,
        bytes[] memory pubkeys,
        uint64[] memory validatorIndices
    ) public {
        require(isHelderChain, "This function can only be called on the Helder chain");
        vm.startBroadcast();
        // Step 1: Create a Mock Pod
        createEigenPod(podOwner);

        // Step 2: Delegate from PodOwner to Operator
        delegateFromPodOwner(podOwner, msg.sender);

        // Step 3: Register the Operator
        registerOperatorToUniFiAVS(signerPk, initialCommitment);

        // Step 4: Add validators to pod and register them to the AVS
        addValidatorsToEigenPodAndRegisterToAVS(podOwner, pubkeys, validatorIndices);
        vm.stopBroadcast();
    }

    // Non-Helder functions

    /// @notice Registers the caller as an operator in the DelegationManager contract (non-Helder only)
    /// @param registeringOperatorDetails The details of the registering operator
    /// @param metadataURI The URI of the operator's metadata
    function registerAsOperator(OperatorDetails memory registeringOperatorDetails, string memory metadataURI) public {
        require(!isHelderChain, "This function can only be called on non-Helder chains");
        vm.startBroadcast();
        delegationManager.registerAsOperator(registeringOperatorDetails, metadataURI);
        vm.stopBroadcast();
    }

    // Common functions for both Helder and non-Helder chains

    /// @notice Registers validators with the UniFiAVSManager using pre-hashed public keys
    /// @param podOwner The address of the pod owner
    /// @param blsPubKeyHashes The hashes of the BLS public keys
    function registerValidatorsToUniFiAVS(address podOwner, bytes32[] memory blsPubKeyHashes) public {
        vm.startBroadcast();
        uniFiAVSManager.registerValidators(podOwner, blsPubKeyHashes);
        vm.stopBroadcast();
    }

    /// @notice Registers validators with the UniFiAVSManager using raw public keys
    /// @param podOwner The address of the pod owner
    /// @param pubkeys The raw public keys of the validators
    function registerValidatorsToUniFiAVS(address podOwner, bytes[] memory pubkeys) public {
        vm.startBroadcast();
        bytes32[] memory pubkeyHashes = new bytes32[](pubkeys.length);
        for (uint256 i = 0; i < pubkeys.length; i++) {
            pubkeyHashes[i] = keccak256(pubkeys[i]);
        }
        uniFiAVSManager.registerValidators(podOwner, pubkeyHashes);
        vm.stopBroadcast();
    }

    /// @notice Registers an operator with the UniFiAVSManager and sets the initial commitment
    /// @param signerPk The private key of the signer
    /// @param initialCommitment The initial commitment for the operator
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

    /// @notice Registers an operator with the UniFiAVSManager using only a delegate key
    /// @param signerPk The private key of the signer
    /// @param delegateKey The delegate key for the operator
    function registerOperatorToUniFiAVSWithDelegateKey(uint256 signerPk, bytes memory delegateKey) public {
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

        uint256 chainIDBitMap = DEFAULT_CHAIN_BITMAP;

        OperatorCommitment memory initialCommitment =
            OperatorCommitment({ delegateKey: delegateKey, chainIDBitMap: chainIDBitMap });

        uniFiAVSManager.setOperatorCommitment(initialCommitment);
        vm.stopBroadcast();
    }

    /// @notice Delegates from PodOwner to Operator by signature
    /// @param staker The address of the staker
    /// @param operator The address of the operator
    /// @param stakerSignatureAndExpiry The staker's signature and expiry
    /// @param approverSignatureAndExpiry The approver's signature and expiry
    /// @param approverSalt The approver's salt
    function delegateFromPodOwnerBySignature(
        address staker,
        address operator,
        SignatureWithExpiry memory stakerSignatureAndExpiry,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) public {
        vm.startBroadcast();
        if (isHelderChain) {
            MockDelegationManager(address(delegationManager)).setOperator(operator, true);
            MockDelegationManager(address(delegationManager)).setDelegation(staker, operator);
        } else {
            delegationManager.delegateToBySignature(
                staker, operator, stakerSignatureAndExpiry, approverSignatureAndExpiry, approverSalt
            );
        }
        vm.stopBroadcast();
    }

    /// @notice Sets the operator's commitment
    /// @param newCommitment The new commitment for the operator
    function setOperatorCommitment(OperatorCommitment memory newCommitment) public {
        vm.startBroadcast();
        uniFiAVSManager.setOperatorCommitment(newCommitment);
        vm.stopBroadcast();
    }

    /// @notice Updates the operator's commitment after the delay period
    function updateOperatorCommitment() public {
        vm.startBroadcast();
        uniFiAVSManager.updateOperatorCommitment();
        vm.stopBroadcast();
    }

    /// @notice Starts the process of deregistering an operator
    function startDeregisterOperator() public {
        vm.startBroadcast();
        uniFiAVSManager.startDeregisterOperator();
        vm.stopBroadcast();
    }

    /// @notice Finishes the process of deregistering an operator
    function finishDeregisterOperator() public {
        vm.startBroadcast();
        uniFiAVSManager.finishDeregisterOperator();
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

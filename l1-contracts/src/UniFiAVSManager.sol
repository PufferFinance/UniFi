// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";
import { IAVSDirectoryExtended } from "./interfaces/EigenLayer/IAVSDirectoryExtended.sol";
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { IEigenPodManager } from "eigenlayer/interfaces/IEigenPodManager.sol";
import { IEigenPod } from "eigenlayer/interfaces/IEigenPod.sol";
import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { BLSSignatureCheckerLib } from "./lib/BLSSignatureCheckerLib.sol";
import { IUniFiAVSManager } from "./interfaces/IUniFiAVSManager.sol";
import { UniFiAVSManagerStorage } from "./UniFiAVSManagerStorage.sol";
import "./structs/ValidatorData.sol";
import "./structs/OperatorData.sol";
import { IndexOutOfBounds } from "./Errors.sol";

contract UniFiAVSManager is
    UniFiAVSManagerStorage,
    IUniFiAVSManager,
    EIP712,
    UUPSUpgradeable,
    AccessManagedUpgradeable
{
    using BN254 for BN254.G1Point;

    IEigenPodManager public immutable EIGEN_POD_MANAGER;
    IDelegationManager public immutable EIGEN_DELEGATION_MANAGER;
    IAVSDirectoryExtended internal immutable AVS_DIRECTORY;

    bytes32 public constant VALIDATOR_REGISTRATION_TYPEHASH =
        keccak256("BN254ValidatorRegistration(bytes delegatePubKey,bytes32 salt,uint256 expiry)");

    modifier podIsDelegated(address podOwner) {
        if (!EIGEN_DELEGATION_MANAGER.isOperator(msg.sender)) {
            revert NotOperator();
        }
        if (!EIGEN_POD_MANAGER.hasPod(podOwner)) {
            revert NoEigenPod();
        }
        if (EIGEN_DELEGATION_MANAGER.delegatedTo(podOwner) != msg.sender) {
            revert NotDelegatedToOperator();
        }
        _;
    }

    constructor(IEigenPodManager eigenPodManager, IDelegationManager eigenDelegationManager, IAVSDirectory avsDirectory)
        EIP712("UniFiAVSManager", "v0.0.1")
    {
        EIGEN_POD_MANAGER = eigenPodManager;
        EIGEN_DELEGATION_MANAGER = eigenDelegationManager;
        AVS_DIRECTORY = IAVSDirectoryExtended(address(avsDirectory));
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
    }

    // EXTERNAL FUNCTIONS

    /**
     * @notice Registers a new operator in the UniFi AVS
     * @dev This function checks if the operator is already registered and if not, registers them in EigenLayer's AVSDirectory
     * @param operatorSignature The signature and associated data for operator registration
     */
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), msg.sender)
                == IAVSDirectory.OperatorAVSRegistrationStatus.REGISTERED
        ) {
            revert OperatorAlreadyRegistered();
        }

        AVS_DIRECTORY.registerOperatorToAVS(msg.sender, operatorSignature);

        emit OperatorRegistered(msg.sender);
    }

    /**
     * @notice Registers validators from a specific EigenPod given pod owner
     * @dev This function checks that the validator is active on the beacon chain and is delegated to the calling Operator, then registers validators associated with the operator
     * @param podOwner The address of the owner of the validator's EigenPod 
     * @param blsPubKeyHashes The BLS public key hashes of the validators that want to be registered
     */
    function registerValidators(address podOwner, bytes32[] calldata blsPubKeyHashes)
        external
        podIsDelegated(podOwner)
    {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), msg.sender)
                == IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED
        ) {
            revert OperatorNotRegistered();
        }
        bytes memory delegateKey = $.operators[msg.sender].commitment.delegateKey;

        if (delegateKey.length == 0) {
            revert DelegateKeyNotSet();
        }

        IEigenPod eigenPod = EIGEN_POD_MANAGER.getPod(podOwner);

        uint256 newValidatorCount = blsPubKeyHashes.length;
        for (uint256 i = 0; i < newValidatorCount; i++) {
            bytes32 blsPubkeyHash = blsPubKeyHashes[i];
            IEigenPod.ValidatorInfo memory validatorInfo = eigenPod.validatorPubkeyHashToInfo(blsPubkeyHash);

            if (validatorInfo.status != IEigenPod.VALIDATOR_STATUS.ACTIVE) {
                revert ValidatorNotActive();
            }

            if ($.validators[blsPubkeyHash].index != 0) {
                revert ValidatorAlreadyRegistered();
            }

            $.validators[blsPubkeyHash] = ValidatorData({
                eigenPod: address(eigenPod),
                index: validatorInfo.validatorIndex,
                operator: msg.sender,
                registeredUntil: type(uint64).max
            });

            $.validatorIndexes[validatorInfo.validatorIndex] = blsPubkeyHash;

            emit ValidatorRegistered(
                podOwner,
                msg.sender,
                delegateKey,
                blsPubkeyHash,
                validatorInfo.validatorIndex
            );
        }

        OperatorData storage operator = $.operators[msg.sender];
        operator.validatorCount += uint128(newValidatorCount);
        operator.startDeregisterOperatorBlock = 0; // Reset the deregistration start block
    }

    /**
     * @notice Deregisters validators from the UniFi AVS
     * @dev This function handles the deregistration process for multiple validators. If the validator's status is not active, a non-owner can deregister the validator. The validator is not immediately deregistered, but instead will be marked as deregistered after the deregistrationDelay and is liable for penalties during this period.
     * @param blsPubKeyHashes The BLS public key hashes of the validators to deregister
     */
    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            bytes32 blsPubKeyHash = blsPubKeyHashes[i];
            ValidatorData storage validator = $.validators[blsPubKeyHash];
            OperatorData storage operator = $.operators[validator.operator];

            if (validator.index == 0) {
                revert ValidatorNotFound();
            }

            if (validator.operator != msg.sender) {
                // eject if no longer active
                IEigenPod eigenPod = IEigenPod(validator.eigenPod);
                IEigenPod.ValidatorInfo memory validatorInfo = eigenPod.validatorPubkeyHashToInfo(blsPubKeyHashes[i]);
                if (validatorInfo.status == IEigenPod.VALIDATOR_STATUS.ACTIVE) {
                    revert NotValidatorOperator();
                }

                // update the actual operator's validator count
                $.operators[validator.operator].validatorCount -= 1;
            } else {
                $.operators[msg.sender].validatorCount -= 1;
            }

            validator.registeredUntil = uint64(block.number) + $.deregistrationDelay;

            emit ValidatorDeregistered(
                IEigenPod(validator.eigenPod).podOwner(),
                validator.operator,
                $.operators[validator.operator].commitment.delegateKey,
                blsPubKeyHash,
                validator.index
            );
        }
    }

    /**
     * @notice Starts the process of deregistering an operator from the UniFi AVS. 
     * @dev This function initiates the deregistration process for an operator. The Operator is not immediately deregistered, but can complete the process by calling finishDeregisterOperator after the deregistrationDelay and is liable for penalties during this period.
     */
    function startDeregisterOperator() external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        OperatorData storage operator = $.operators[msg.sender];

        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), msg.sender)
                == IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED
        ) {
            revert OperatorNotRegistered();
        }

        if (operator.validatorCount > 0) {
            revert OperatorHasValidators();
        }

        if (operator.startDeregisterOperatorBlock != 0) {
            revert DeregistrationAlreadyStarted();
        }

        operator.startDeregisterOperatorBlock = block.number;

        emit OperatorDeregisterStarted(msg.sender);
    }

    /**
     * @notice Finishes the process of deregistering an operator from the UniFi AVS.
     * @dev This function completes the deregistration process for an operator after the delay period
     */
    function finishDeregisterOperator() external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        OperatorData storage operator = $.operators[msg.sender];

        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), msg.sender)
                == IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED
        ) {
            revert OperatorNotRegistered();
        }

        if (operator.startDeregisterOperatorBlock == 0) {
            revert DeregistrationNotStarted();
        }

        if (block.number < operator.startDeregisterOperatorBlock + $.deregistrationDelay) {
            revert DeregistrationDelayNotElapsed();
        }

        AVS_DIRECTORY.deregisterOperatorFromAVS(msg.sender);

        delete $.operators[msg.sender];

        emit OperatorDeregistered(msg.sender);
    }

    function getOperator(address operator) external view returns (OperatorDataExtended memory) {
        return _getOperator(operator);
    }

    function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorDataExtended memory) {
        return _getValidator(blsPubKeyHash);
    }

    function getValidator(uint256 validatorIndex) external view returns (ValidatorDataExtended memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        bytes32 blsPubKeyHash = $.validatorIndexes[validatorIndex];
        return _getValidator(blsPubKeyHash);
    }

    function getValidators(bytes32[] calldata blsPubKeyHashes) external view returns (ValidatorDataExtended[] memory) {
        ValidatorDataExtended[] memory validators = new ValidatorDataExtended[](blsPubKeyHashes.length);
        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            validators[i] = _getValidator(blsPubKeyHashes[i]);
        }

        return validators;
    }

    /**
     * @notice Sets the commitment for an operator
     * @dev This function initiates a change in the operator's commitment
     * @param newCommitment The new commitment to set for the operator
     */
    function setOperatorCommitment(OperatorCommitment memory newCommitment) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), msg.sender)
                == IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED
        ) {
            revert OperatorNotRegistered();
        }

        operator.pendingCommitment = newCommitment;
        operator.commitmentValidAfter = block.number + $.deregistrationDelay;

        emit OperatorCommitmentChangeInitiated(
            msg.sender, operator.commitment, newCommitment, operator.commitmentValidAfter
        );
    }

    /**
     * @notice Updates the operator's commitment after the delay period
     * @dev This function finalizes the commitment change for an operator
     */
    function updateOperatorCommitment() external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        if (operator.commitmentValidAfter == 0 || block.number < operator.commitmentValidAfter) {
            revert CommitmentChangeNotReady();
        }

        OperatorCommitment memory oldCommitment = operator.commitment;
        operator.commitment = operator.pendingCommitment;

        // Reset pending data
        delete operator.pendingCommitment;
        delete operator.commitmentValidAfter;

        emit OperatorCommitmentSet(msg.sender, oldCommitment, operator.commitment);
    }

    /**
     * @notice Sets a new deregistration delay
     * @dev This function can only be called by authorized addresses
     * @param newDelay The new deregistration delay to set
     */
    function setDeregistrationDelay(uint64 newDelay) external restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        uint64 oldDelay = $.deregistrationDelay;
        $.deregistrationDelay = newDelay;
        emit DeregistrationDelaySet(oldDelay, newDelay);
    }

    function getDeregistrationDelay() external view returns (uint64) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.deregistrationDelay;
    }

    /**
     * @notice Converts a bitmap of chain IDs to an array of chain IDs
     * @dev This function interprets each bit in the bitmap as a flag for a chain ID
     * @param bitmap The bitmap representing chain IDs
     * @return An array of chain IDs (as bytes4) corresponding to the set bits in the bitmap
     */
    function bitmapToChainIDs(uint256 bitmap) public view returns (bytes4[] memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        bytes4[] memory result = new bytes4[](256);
        uint256 count = 0;
        for (uint256 i = 0; i < 256; i++) {
            if ((bitmap & (1 << i)) != 0) {
                result[count] = $.chainIDs[i];
                count++;
            }
        }
        // Resize the array to remove unused elements
        assembly {
            mstore(result, count)
        }
        return result;
    }

    /**
     * @notice Sets a chain ID at a specific index
     * @dev This function can only be called by authorized addresses
     * @param index The index at which to set the chain ID (0-255)
     * @param chainID The chain ID to set
     */
    function setChainID(uint256 index, bytes4 chainID) external restricted {
        if (index >= 256) revert IndexOutOfBounds();
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        $.chainIDs[index] = chainID;
    }

    function getChainID(uint256 index) external view returns (bytes4) {
        if (index >= 256) revert IndexOutOfBounds();
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.chainIDs[index];
    }

    // INTERNAL FUNCTIONS

    function _getOperator(address operator) internal view returns (OperatorDataExtended memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operatorData = $.operators[operator];

        OperatorCommitment memory activeCommitment = operatorData.commitment;
        if (operatorData.commitmentValidAfter != 0 && block.number >= operatorData.commitmentValidAfter) {
            activeCommitment = operatorData.pendingCommitment;
        }

        return OperatorDataExtended({
            validatorCount: operatorData.validatorCount,
            commitment: activeCommitment,
            pendingCommitment: operatorData.pendingCommitment,
            startDeregisterOperatorBlock: operatorData.startDeregisterOperatorBlock,
            isRegistered: AVS_DIRECTORY.avsOperatorStatus(address(this), operator)
                == IAVSDirectory.OperatorAVSRegistrationStatus.REGISTERED,
            commitmentValidAfter: operatorData.commitmentValidAfter
        });
    }

    function _getValidator(bytes32 blsPubKeyHash) internal view returns (ValidatorDataExtended memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        ValidatorData memory validatorData = $.validators[blsPubKeyHash];

        if (validatorData.index != 0) {
            IEigenPod eigenPod = IEigenPod(validatorData.eigenPod);
            IEigenPod.ValidatorInfo memory validatorInfo = eigenPod.validatorPubkeyHashToInfo(blsPubKeyHash);

            bool backedByStake = EIGEN_DELEGATION_MANAGER.delegatedTo(eigenPod.podOwner()) == validatorData.operator;

            OperatorData storage operatorData = $.operators[validatorData.operator];
            OperatorCommitment memory activeCommitment = operatorData.commitment;
            if (operatorData.commitmentValidAfter != 0 && block.number >= operatorData.commitmentValidAfter) {
                activeCommitment = operatorData.pendingCommitment;
            }

            return ValidatorDataExtended({
                operator: validatorData.operator,
                eigenPod: validatorData.eigenPod,
                validatorIndex: validatorInfo.validatorIndex,
                status: validatorInfo.status,
                delegateKey: activeCommitment.delegateKey,
                chainIDBitMap: activeCommitment.chainIDBitMap,
                backedByStake: backedByStake,
                registered: block.number < validatorData.registeredUntil
            });
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

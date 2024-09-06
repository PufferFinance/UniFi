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
import { IUniFiAVSManager } from "./interfaces/IUniFiAVSManager.sol";
import { UniFiAVSManagerStorage } from "./UniFiAVSManagerStorage.sol";
import "./structs/ValidatorData.sol";
import "./structs/OperatorData.sol";

contract UniFiAVSManager is UniFiAVSManagerStorage, IUniFiAVSManager, UUPSUpgradeable, AccessManagedUpgradeable {
    /**
     * @notice The EigenPodManager
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    IEigenPodManager public immutable override EIGEN_POD_MANAGER;
    /**
     * @notice The EigenDelegationManager
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    IDelegationManager public immutable override EIGEN_DELEGATION_MANAGER;
    /**
     * @notice The AVSDirectory contract
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    IAVSDirectoryExtended public immutable override AVS_DIRECTORY;

    /**
     * @dev Modifier to check if the pod is delegated to the msg.sender
     * @param podOwner The address of the pod owner
     */
    modifier podIsDelegatedToMsgSender(address podOwner) {
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

    modifier registeredOperator(address operator) {
        if (
            AVS_DIRECTORY.avsOperatorStatus(address(this), operator)
                == IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED
        ) {
            revert OperatorNotRegistered();
        }
        _;
    }

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        IEigenPodManager eigenPodManager,
        IDelegationManager eigenDelegationManager,
        IAVSDirectory avsDirectory
    ) {
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
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external restricted {
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
        podIsDelegatedToMsgSender(podOwner)
        registeredOperator(msg.sender)
        restricted
    {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

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

            emit ValidatorRegistered(podOwner, msg.sender, delegateKey, blsPubkeyHash, validatorInfo.validatorIndex);
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
    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            bytes32 blsPubKeyHash = blsPubKeyHashes[i];
            ValidatorData storage validator = $.validators[blsPubKeyHash];

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
    function startDeregisterOperator() external registeredOperator(msg.sender) restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        OperatorData storage operator = $.operators[msg.sender];

        if (operator.validatorCount > 0) {
            revert OperatorHasValidators();
        }

        if (operator.startDeregisterOperatorBlock != 0) {
            revert DeregistrationAlreadyStarted();
        }

        operator.startDeregisterOperatorBlock = uint128(block.number);

        emit OperatorDeregisterStarted(msg.sender);
    }

    /**
     * @notice Finishes the process of deregistering an operator from the UniFi AVS.
     * @dev This function completes the deregistration process for an operator after the delay period
     */
    function finishDeregisterOperator() external registeredOperator(msg.sender) restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        OperatorData storage operator = $.operators[msg.sender];

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


    /**
     * @notice Sets the commitment for an operator
     * @dev This function initiates a change in the operator's commitment
     * @param newCommitment The new commitment to set for the operator
     */
    function setOperatorCommitment(OperatorCommitment memory newCommitment) external registeredOperator(msg.sender) restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        operator.pendingCommitment = newCommitment;
        operator.commitmentValidAfter = uint128(block.number + $.deregistrationDelay);

        emit OperatorCommitmentChangeInitiated(
            msg.sender, operator.commitment, newCommitment, operator.commitmentValidAfter
        );
    }

    /**
     * @notice Updates the operator's commitment after the delay period
     * @dev This function finalizes the commitment change for an operator
     */
    function updateOperatorCommitment() external restricted {
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

    /**
     * @notice Sets a chain ID at a specific index
     * @dev This function can only be called by authorized addresses
     * @param index The index at which to set the chain ID (1-255)
     * @param chainID The chain ID to set. if 0, then the chainId is being removed
     */
    function setChainID(uint8 index, uint256 chainID) external restricted {
        if (index == 0) revert IndexOutOfBounds();

        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        $.bitmapIndexToChainId[index] = chainID;
        $.chainIdToBitmapIndex[chainID] = index;
    }

    // GETTERS

    function getDeregistrationDelay() external view returns (uint64) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.deregistrationDelay;
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
     * @notice Converts a bitmap of chain IDs to an array of chain IDs
     * @dev This function interprets each bit in the bitmap as a flag for a chain ID
     * @param bitmap The bitmap representing chain IDs
     * @return An array of chain IDs (as bytes4) corresponding to the set bits in the bitmap
     */
    function bitmapToChainIDs(uint256 bitmap) public view returns (uint256[] memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        uint256[] memory result = new uint256[](256);
        uint8 count = 0;
        for (uint8 i = 1; i < 255; i++) {
            if ((bitmap & (1 << i)) != 0) {
                result[count] = $.bitmapIndexToChainId[i];
                count++;
            }
        }
        // Resize the array to remove unused elements
        assembly {
            mstore(result, count)
        }
        return result;
    }

    function getChainID(uint8 index) external view returns (uint256) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.bitmapIndexToChainId[index];
    }

    function getBitmapIndex(uint256 chainID) external view returns (uint8) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        uint8 index = $.chainIdToBitmapIndex[chainID];

        return index; // if 0 then there's no index set
    }

    /**
     * @notice Checks if a validator is registered for a specific chain ID.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @param chainId The chain ID to check.
     * @return bool True if the validator is registered for the given chain ID, false otherwise.
     */
    function isValidatorInChainId(bytes32 blsPubKeyHash, uint256 chainId) external view returns (bool) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        ValidatorData storage validator = $.validators[blsPubKeyHash];

        if (validator.index == 0) {
            return false; // Validator not found
        }

        OperatorData storage operator = $.operators[validator.operator];
        OperatorCommitment memory activeCommitment = operator.commitment;

        uint8 bitmapIndex = $.chainIdToBitmapIndex[chainId];
        if (bitmapIndex == 0) {
            return false; // ChainId not set
        }

        return (activeCommitment.chainIDBitMap & (1 << (bitmapIndex - 1))) != 0;
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

    function _getValidator(bytes32 blsPubKeyHash) internal view returns (ValidatorDataExtended memory validator) {
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

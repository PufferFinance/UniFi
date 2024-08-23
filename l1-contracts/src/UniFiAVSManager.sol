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

error CommitmentChangeNotReady();

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

    // Mapping to store chainIDs
    mapping(uint256 => bytes4) private chainIDs;

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

        if ($.operators[msg.sender].commitment.delegateKey.length == 0) {
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

            // Check if the validator already exists
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
                $.operators[msg.sender].commitment.delegateKey,
                blsPubkeyHash,
                validatorInfo.validatorIndex
            );
        }

        OperatorData storage operator = $.operators[msg.sender];
        operator.validatorCount += uint128(newValidatorCount);
        operator.startDeregisterOperatorBlock = 0; // Reset the deregistration start block
    }

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

    function updateOperatorCommitment() external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        if (operator.commitmentValidAfter == 0 || block.number < operator.commitmentValidAfter) {
            revert CommitmentChangeNotReady();
        }

        OperatorCommitment memory oldCommitment = operator.commitment;
        operator.commitment = operator.pendingCommitment;

        // Reset pending data
        operator.pendingCommitment = OperatorCommitment({ delegateKey: "", chainIDBitMap: 0 });
        operator.commitmentValidAfter = 0;

        emit OperatorCommitmentSet(msg.sender, oldCommitment, operator.commitment);
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

    function setDeregistrationDelay(uint64 newDelay) external restricted {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        uint64 oldDelay = $.deregistrationDelay;
        $.deregistrationDelay = newDelay;
        emit DeregistrationDelaySet(oldDelay, newDelay);
    }

    function getDeregistrationDelay() external returns (uint64) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.deregistrationDelay;
    }

    function bitmapToChainIDs(uint256 bitmap) public view returns (bytes4[] memory) {
        bytes4[] memory result = new bytes4[](256);
        uint256 count = 0;
        for (uint256 i = 0; i < 256; i++) {
            if ((bitmap & (1 << i)) != 0) {
                result[count] = chainIDs[i];
                count++;
            }
        }
        // Resize the array to remove unused elements
        assembly {
            mstore(result, count)
        }
        return result;
    }

    function setChainID(uint256 index, bytes4 chainID) external restricted {
        require(index < 256, "Index out of bounds");
        chainIDs[index] = chainID;
    }

    function getChainID(uint256 index) external view returns (bytes4) {
        require(index < 256, "Index out of bounds");
        return chainIDs[index];
    }
}

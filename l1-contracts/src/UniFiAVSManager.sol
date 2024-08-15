// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ISignatureUtils} from "eigenlayer/interfaces/ISignatureUtils.sol";
import {IAVSDirectory} from "eigenlayer/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "eigenlayer/interfaces/IDelegationManager.sol";
import {IEigenPodManager} from "eigenlayer/interfaces/IEigenPodManager.sol";
import {IEigenPod} from "eigenlayer/interfaces/IEigenPod.sol";
import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {BLSSignatureCheckerLib} from "./lib/BLSSignatureCheckerLib.sol";
import {IUniFiAVSManager} from "./interfaces/IUniFiAVSManager.sol";
import {UniFiAVSManagerStorage} from "./UniFiAVSManagerStorage.sol";
import "./structs/ValidatorRegistrationParams.sol";
import "./structs/ValidatorData.sol";
import "./structs/OperatorData.sol";
import "./structs/PreConferInfo.sol";

error InvalidOperator();
error OperatorAlreadyRegistered();
error NotPodOwner();
error ValidatorNotFound();
error DelegateKeyNotSet();

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
    IAVSDirectory internal immutable AVS_DIRECTORY;

    bytes32 public constant VALIDATOR_REGISTRATION_TYPEHASH =
        keccak256(
            "BN254ValidatorRegistration(bytes delegatePubKey,bytes32 salt,uint256 expiry)"
        );

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

    constructor(
        IEigenPodManager eigenPodManager,
        IDelegationManager eigenDelegationManager,
        IAVSDirectory avsDirectory
    ) EIP712("UniFiAVSManager", "v0.0.1") {
        EIGEN_POD_MANAGER = eigenPodManager;
        EIGEN_DELEGATION_MANAGER = eigenDelegationManager;
        AVS_DIRECTORY = avsDirectory;
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
    }

    function registerOperator(
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        if ($.operators[msg.sender].registered) {
            revert OperatorAlreadyRegistered();
        }

        if (operatorSignature.expiry < block.timestamp) {
            revert SignatureExpired();
        }

        if ($.operatorSalts[operatorSignature.salt]) {
            revert InvalidOperatorSalt();
        }

        $.operatorSalts[operatorSignature.salt] = true;

        AVS_DIRECTORY.registerOperatorToAVS(msg.sender, operatorSignature);

        $.operators[msg.sender].registered = true;

        emit OperatorRegistered(msg.sender);
    }

    function registerValidators(
        address podOwner,
        bytes32[] calldata blsPubKeyHashes
    ) podIsDelegated(podOwner) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        if (!$.operators[msg.sender].registered) {
            revert OperatorNotRegistered();
        }

        if ($.operators[msg.sender].delegateKey.length == 0) {
            revert DelegateKeyNotSet();
        }

        IEigenPod eigenPod = EIGEN_POD_MANAGER.getPod(podOwner);

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            bytes32 blsPubkeyHash = blsPubKeyHashes[i];
            IEigenPod.ValidatorInfo memory validatorInfo = eigenPod
                .validatorPubkeyHashToInfo(blsPubkeyHash);

            if (validatorInfo.status != IEigenPod.VALIDATOR_STATUS.ACTIVE) {
                revert ValidatorNotActive();
            }

            // Check if the validator already exists
            if ($.validators[blsPubkeyHash].registered) {
                revert ValidatorAlreadyRegistered();
            }

            $.validators[blsPubkeyHash] = ValidatorData({
                eigenPod: address(eigenPod),
                validatorIndex: validatorInfo.validatorIndex,
                operator: msg.sender,
                registered: true
            });

            $.validatorIndexes[validatorInfo.validatorIndex] = blsPubkeyHash;

            $.operators[msg.sender].validatorCount++;

            emit ValidatorRegistered(podOwner, $.operators[msg.sender].delegateKey, blsPubkeyHash, validatorInfo.validatorIndex);
        }
    }

    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        if (!operator.registered) {
            revert OperatorNotRegistered();
        }

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            bytes32 blsPubKeyHash = blsPubKeyHashes[i];
            ValidatorData storage validator = $.validators[blsPubKeyHash];
            
            if (!validator.registered || validator.operator != msg.sender) {
                revert ValidatorNotFound();
            }

            validator.registered = false;
            operator.validatorCount--;

            emit ValidatorDeregistered(blsPubKeyHash, validator.validatorIndex, address(validator.eigenPod), msg.sender);
        }
    }

    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];

        if (!operator.registered) {
            revert OperatorNotRegistered();
        }

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            bytes32 blsPubKeyHash = blsPubKeyHashes[i];
            ValidatorData storage validator = $.validators[blsPubKeyHash];
            
            if (!validator.registered || validator.operator != msg.sender) {
                revert ValidatorNotFound();
            }

            validator.registered = false;
            operator.validatorCount--;

            emit ValidatorDeregistered(blsPubKeyHash, validator.validatorIndex, address(validator.eigenPod), msg.sender);
        }
    }

    function deregisterOperator() external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();

        OperatorData storage operator = $.operators[msg.sender];

        if (!operator.registered) {
            revert OperatorNotRegistered();
        }

        if (operator.validatorCount > 0) {
            revert OperatorHasValidators();
        }

        AVS_DIRECTORY.deregisterOperatorFromAVS(msg.sender);

        delete $.operators[msg.sender];

        emit OperatorDeregistered(msg.sender);
    }

    function getOperator(
        address operator
    ) external view returns (OperatorData memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        return $.operators[operator];
    }

    function getValidator(bytes32 blsPubKeyHash) external view returns (PreConferInfo memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        ValidatorData memory validatorData = $.validators[blsPubKeyHash];
        
        IEigenPod eigenPod = IEigenPod(validatorData.eigenPod);
        IEigenPod.ValidatorInfo memory validatorInfo = eigenPod.validatorPubkeyHashToInfo(blsPubKeyHash);

        bool backedByStake = EIGEN_DELEGATION_MANAGER.delegatedTo(eigenPod.podOwner()) == validatorData.operator;
        
        return PreConferInfo({
            data: validatorData,
            validatorIndex: validatorInfo.validatorIndex,
            status: validatorInfo.status,
            backedByStake: backedByStake,
            delegateKey: $.operators[validatorData.operator].delegateKey
        });
    }

    function getValidator(uint256 validatorIndex) external view returns (PreConferInfo memory) {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        bytes32 blsPubKeyHash = $.validatorIndexes[validatorIndex];
        return this.getValidator(blsPubKeyHash);
    }

    function getValidators(bytes32[] calldata blsPubKeyHashes) external view returns (PreConferInfo[] memory) {
        PreConferInfo[] memory validators = new PreConferInfo[](blsPubKeyHashes.length);
        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            validators[i] = this.getValidator(blsPubKeyHashes[i]);
        }
        return validators;
    }

    function setOperatorDelegateKey(bytes memory newDelegateKey) external {
        UniFiAVSStorage storage $ = _getUniFiAVSManagerStorage();
        OperatorData storage operator = $.operators[msg.sender];
        
        if (!operator.registered) {
            revert OperatorNotRegistered();
        }

        operator.delegateKey = newDelegateKey;
        emit OperatorDelegateKeySet(msg.sender, newDelegateKey);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override restricted {}
}

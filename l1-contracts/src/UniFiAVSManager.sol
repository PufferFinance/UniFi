// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { IEigenPodManager } from "eigenlayer/interfaces/IEigenPodManager.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import { IEigenPod } from "eigenlayer/interfaces/IEigenPod.sol";
import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { BLSSingatureCheckerLib } from "./lib/BLSSingatureCheckerLib.sol";
import { IUniFiAVSManager } from "./interfaces/IUniFiAVSManager.sol";

contract UniFiAVSManager is EIP712, UUPSUpgradeable, AccessManagedUpgradeable, IUniFiAVSManager {
    using BN254 for BN254.G1Point;

    IEigenPodManager public immutable EIGEN_POD_MANAGER;
    IDelegationManager public immutable EIGEN_DELEGATION_MANAGER;
    IAVSDirectory internal immutable AVS_DIRECTORY;

    bytes32 public constant VALIDATOR_REGISTRATION_TYPEHASH =
        keccak256("BN254ValidatorRegistration(bytes32 ecdsaPubKeyHash)");

    mapping(bytes32 => ValidatorData) public registeredValidators;

    modifier validOperator(address podOwner) {
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
        AVS_DIRECTORY = avsDirectory;
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
    }

    function registerOperator(address podOwner, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)
        external
        validOperator(podOwner)
    {
        AVS_DIRECTORY.registerOperatorToAVS(msg.sender, operatorSignature);

        emit OperatorRegistered(msg.sender, podOwner);
    }

    function registerValidator(address podOwner, ValidatorRegistrationParams calldata params)
        external
        validOperator(podOwner)
    {
        IEigenPod eigenPod = EIGEN_POD_MANAGER.getPod(podOwner);
        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);

        if (eigenPod.validatorStatus(pubkeyHash) != IEigenPod.VALIDATOR_STATUS.ACTIVE) {
            revert ValidatorNotActive();
        }

        BN254.G1Point memory messageHash = validatorRegistrationMessageHash(params.ecdsaPubKeyHash);

        if (
            !BLSSingatureCheckerLib.isBlsSignatureValid(
                params.pubkeyG1, params.pubkeyG2, params.registrationSignature, messageHash
            )
        ) {
            revert InvalidSignature();
        }

        registeredValidators[params.ecdsaPubKeyHash] =
            ValidatorData({ blsPubKeyHash: params.ecdsaPubKeyHash, eigenPod: address(eigenPod) });

        emit ValidatorRegistered(podOwner, params.ecdsaPubKeyHash, pubkeyHash);
    }

    function deregisterOperator() external {
        AVS_DIRECTORY.deregisterOperatorFromAVS(msg.sender);

        emit OperatorDeregistered(msg.sender);
    }

    function validatorRegistrationMessageHash(bytes32 ecdsaPubKeyHash) public view returns (BN254.G1Point memory) {
        return BN254.hashToG1(_hashTypedDataV4(keccak256(abi.encode(VALIDATOR_REGISTRATION_TYPEHASH, ecdsaPubKeyHash)))); // TODO add salt and expiry?
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

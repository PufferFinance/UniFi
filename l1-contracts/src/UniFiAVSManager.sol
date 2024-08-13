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
        keccak256("BN254ValidatorRegistration(bytes32 ecdsaPubKeyHash,bytes32 salt,uint256 expiry)");

    bytes32 public constant VALIDATOR_DEREGISTRATION_TYPEHASH =
        keccak256("BN254ValidatorDeregistration(bytes32 salt,uint256 expiry)");

    mapping(bytes32 => ValidatorData) internal validators;
    mapping(address => OperatorData) internal operators;
    mapping(bytes32 => bool) internal salts;

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

        if (params.expiry < block.timestamp) {
            revert RegistrationExpired();
        }

        if (salts[params.salt]) {
            revert InvalidRegistrationSalt();
        }

        salts[params.salt] = true;

        BN254.G1Point memory messageHash =
            blsMessageHash(VALIDATOR_REGISTRATION_TYPEHASH, params.ecdsaPubKeyHash, params.salt, params.expiry);

        if (
            !BLSSingatureCheckerLib.isBlsSignatureValid(
                params.pubkeyG1, params.pubkeyG2, params.registrationSignature, messageHash
            )
        ) {
            revert InvalidSignature();
        }

        validators[pubkeyHash] = ValidatorData({ ecdsaPubKeyHash: params.ecdsaPubKeyHash, eigenPod: address(eigenPod) });

        emit ValidatorRegistered(podOwner, params.ecdsaPubKeyHash, pubkeyHash);
    }

    function deregisterValidator(bytes32[] calldata blsPubKeyHashs) external {
        for (uint256 i = 0; i < blsPubKeyHashs.length; i++) {
            ValidatorData memory validator = validators[blsPubKeyHashs[i]];

            IEigenPod eigenPod = IEigenPod(validator.eigenPod);

            if (EIGEN_DELEGATION_MANAGER.delegatedTo(eigenPod.podOwner()) != msg.sender) {
                revert NotDelegatedToOperator();
            }

            OperatorData storage operator = operators[msg.sender];

            operator.validatorCount--;
            delete validators[blsPubKeyHashs[i]];

            emit ValidatorDeregistered(blsPubKeyHashs[i]);
        }
    }

    function deregisterOperator() external {
        OperatorData storage operator = operators[msg.sender];

        if (operator.validatorCount > 0) {
            revert OperatorHasValidators();
        }

        AVS_DIRECTORY.deregisterOperatorFromAVS(msg.sender);

        emit OperatorDeregistered(msg.sender);
    }

    function blsMessageHash(bytes32 typeHash, bytes32 ecdsaPubKeyHash, bytes32 salt, uint256 expiry)
        public
        view
        returns (BN254.G1Point memory)
    {
        return BN254.hashToG1(_hashTypedDataV4(keccak256(abi.encode(typeHash, ecdsaPubKeyHash, salt, expiry))));
    }

    /**
     * @notice Returns validator data for the given BLS public key hash.
     * @param blsPubKeyHash The hash of the BLS public key.
     * @return ValidatorData The data associated with the validator.
     */
    function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorData memory) {
        return validators[blsPubKeyHash];
    }

    /**
     * @notice Returns operator data for the given address.
     * @param operator The address of the operator.
     * @return OperatorData The data associated with the operator.
     */
    function getOperator(address operator) external view returns (OperatorData memory) {
        return operators[operator];
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

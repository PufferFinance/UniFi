// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract.
 */
interface IUniFiAVSManager {
    /**
     * @notice Struct used when registering a new ECDSA key
     * @param registrationSignature The registration message signed by the private key of the validator
     * @param pubkeyG1 The corresponding G1 public key of the validator
     * @param pubkeyG2 The corresponding G2 public key of the validator
     * @param ecdsaPubKeyHash The hash of the ECDSA public key to be registered
     * @param salt The salt used to generate the signature
     * @param expiry The expiration timestamp (UTC) of the signature
     */
    struct ValidatorRegistrationParams {
        BN254.G1Point registrationSignature;
        BN254.G1Point pubkeyG1;
        BN254.G2Point pubkeyG2;
        bytes32 ecdsaPubKeyHash;
        bytes32 salt;
        uint256 expiry;
    }

    /**
     * @notice Struct to hold validator data
     * @param ecdsaPubKeyHash The hash of the ECDSA public key
     * @param eigenPod The address of the associated EigenPod
     */
    struct ValidatorData {
        bytes32 ecdsaPubKeyHash;
        address eigenPod;
    }

    error RegistrationExpired();
    error InvalidRegistrationSalt();
    error OperatorHasValidators();
    error NotOperator();
    error NoEigenPod();
    error NotDelegatedToOperator();
    error ValidatorNotActive();
    error InvalidSignature();
    error OperatorAlreadyExists();

    event OperatorCreated(address indexed operator, address indexed podOwner);
    event OperatorRegistered(address indexed operator, address indexed podOwner);
    event ValidatorRegistered(address indexed podOwner, bytes32 indexed ecdsaPubKeyHash, bytes32 blsPubKeyHash);
    event OperatorDeregistered(address indexed operator);
    event ValidatorDeregistered(bytes32 blsPubKeyHash);

    function createOperator() external returns (address);
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external;
    function registerValidator(address podOwner, ValidatorRegistrationParams calldata params) external;
    function deregisterValidator(bytes32[] calldata blsPubKeyHashs) external;
    function deregisterOperator() external;
    function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorData memory);
    function getValidator(uint256 validatorIndex) external view returns (ValidatorData memory);
    function getOperator(address operator) external view returns (OperatorData memory);
    function registerOperatorToAVS(
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;
    function deregisterOperatorFromAVS(bytes calldata quorumNumbers) external;
    function updateOperatorAVSSocket(string memory socket) external;
}

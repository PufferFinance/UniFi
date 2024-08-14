// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract, handling operator and validator registration.
 */
interface IUniFiAVSManager {
    /**
     * @notice Struct used when registering a new ECDSA key.
     * @param registrationSignature The registration message signed by the private key of the validator.
     * @param pubkeyG1 The corresponding G1 public key of the validator.
     * @param pubkeyG2 The corresponding G2 public key of the validator.
     * @param ecdsaPubKeyHash The hash of the ECDSA public key to be registered.
     * @param salt The salt used to generate the signature.
     * @param expiry The expiration timestamp (UTC) of the signature.
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
     * @notice Struct to hold validator data.
     * @param ecdsaPubKeyHash The hash of the ECDSA public key.
     * @param eigenPod The address of the associated EigenPod.
     * @param operator The address of the associated operator.
     */
    struct ValidatorData {
        bytes32 ecdsaPubKeyHash;
        address eigenPod;
        address operator;
    }

    /**
     * @notice Struct to hold operator data.
     * @param validatorCount The count of validators associated with the operator.
     * @param podOwner The address of the associated EigenPod owner.
     */
    struct OperatorData {
        uint32 validatorCount;
        address podOwner;
    }

    /**
     * @notice Error thrown when a registration attempt is made with an expired timestamp.
     */
    error RegistrationExpired();

    /**
     * @notice Error thrown when an invalid salt is provided for registration.
     */
    error InvalidRegistrationSalt();

    /**
     * @notice Error thrown when an operator attempts to deregister but still has associated validators.
     */
    error OperatorHasValidators();

    /**
     * @notice Error thrown when the sender is not recognized as an operator.
     */
    error NotOperator();

    /**
     * @notice Error thrown when the pod owner does not have an EigenPod.
     */
    error NoEigenPod();

    /**
     * @notice Error thrown when the pod owner has not delegated to the operator.
     */
    error NotDelegatedToOperator();

    /**
     * @notice Error thrown when the validator is not active during registration.
     */
    error ValidatorNotActive();

    /**
     * @notice Error thrown when an invalid signature is provided.
     */
    error InvalidSignature();

    /**
     * @notice Event emitted when an operator is registered to AVS.
     * @param operator The address of the registered operator.
     * @param podOwner The address of the pod owner.
     */
    event OperatorRegistered(address indexed operator, address indexed podOwner);

    /**
     * @notice Event emitted when a validator is registered.
     * @param podOwner The address of the pod owner.
     * @param ecdsaPubKeyHash The hash of the ECDSA public key.
     * @param blsPubKeyHash The hash of the BLS public key.
     */
    event ValidatorRegistered(address indexed podOwner, bytes32 indexed ecdsaPubKeyHash, bytes32 blsPubKeyHash);

    /**
     * @notice Event emitted when an operator is deregistered from AVS.
     * @param operator The address of the deregistered operator.
     */
    event OperatorDeregistered(address indexed operator);

    /**
     * @notice Event emitted when a validator is deregistered.
     * @param blsPubKeyHash The hash of the BLS public key.
     */
    event ValidatorDeregistered(bytes32 blsPubKeyHash);

    /**
     * @notice Registers an operator to AVS.
     * @param podOwner The address of the pod owner.
     * @param operatorSignature The signature of the operator with salt and expiry.
     */
    function registerOperator(address podOwner, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)
        external;

    /**
     * @notice Registers a validator.
     * @param podOwner The address of the pod owner.
     * @param params The parameters for validator registration.
     */
    function registerValidator(address podOwner, ValidatorRegistrationParams calldata params) external;

    /**
     * @notice Deregisters a validator.
     * @param blsPubKeyHashs The hashes of the BLS public keys to deregister.
     */
    function deregisterValidator(bytes32[] calldata blsPubKeyHashs) external;

    /**
     * @notice Deregisters an operator from AVS.
     * @param operator The address of the operator to deregister.
     */
    function deregisterOperator(address operator) external;

    /**
     * @notice Returns validator data for the given BLS public key hash.
     * @param blsPubKeyHash The hash of the BLS public key.
     * @return ValidatorData The data associated with the validator.
     */
    function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorData memory);

    /**
     * @notice Returns validator data for the given validator index.
     * @param validatorIndex The index of the validator.
     * @return ValidatorData The data associated with the validator.
     */
    function getValidator(uint256 validatorIndex) external view returns (ValidatorData memory);

    /**
     * @notice Returns operator data for the given address.
     * @param operator The address of the operator.
     * @return OperatorData The data associated with the operator.
     */
    function getOperator(address operator) external view returns (OperatorData memory);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import "../structs/ValidatorData.sol";
import "../structs/OperatorData.sol";
import "../structs/ValidatorDataExtended.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract, which manages operators and validators in the UniFi AVS system.
 * @dev This interface defines the main functions and events for operator and validator management.
 */
interface IUniFiAVSManager {
    /**
     * @notice Thrown when an operator registration has expired.
     */
    error RegistrationExpired();

    /**
     * @notice Thrown when an operator registration salt is reused.
     */
    error InvalidOperatorSalt();

    /**
     * @notice Thrown when an operator registration signature has expired.
     */
    error SignatureExpired();

    /**
     * @notice Thrown when an operator with remaining validators attempts to deregister.
     */
    error OperatorHasValidators();

    /**
     * @notice Thrown when a non-operator attempts an operator-only action.
     */
    error NotOperator();

    /**
     * @notice Thrown when an EigenPod does not exist for a given address.
     */
    error NoEigenPod();

    /**
     * @notice Thrown when an address is not delegated to the expected operator.
     */
    error NotDelegatedToOperator();

    /**
     * @notice Thrown when a validator is not in the active state in an EigenPod.
     */
    error ValidatorNotActive();

    /**
     * @notice Thrown when an operator already exists.
     */
    error OperatorAlreadyExists();

    /**
     * @notice Thrown when an operator is not registered.
     */
    error OperatorNotRegistered();

    /**
     * @notice Thrown when an operator is already registered.
     */
    error OperatorAlreadyRegistered();

    /**
     * @notice Thrown when a non-operator attempts to deregister a validator.
     */
    error NotValidatorOperator();

    /**
     * @notice Thrown when a validator is already registered to an operator.
     */
    error ValidatorAlreadyRegistered();

    /**
     * @notice Thrown when an operator's delegate key is not set.
     */
    error DelegateKeyNotSet();
    error InvalidOperator();
    error NotPodOwner();
    error ValidatorNotFound();

    /**
     * @notice Emitted when a new operator is registered in the UniFi AVS system.
     * @param operator The address of the registered operator.
     */
    event OperatorRegistered(address indexed operator);

    /**
     * @notice Emitted when a validator's delegate key is modified.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @param newDelegateKey The new delegate key for the validator.
     */
    event ValidatorDelegateKeyModified(bytes32 indexed blsPubKeyHash, bytes newDelegateKey);

    /**
     * @notice Emitted when a new validator is registered in the UniFi AVS system.
     * @param podOwner The address of the validator's EigenPod owner.
     * @param delegatePubKey The delegate public key for the validator.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @param validatorIndex The beacon chain validator index.
     */
    event ValidatorRegistered(
        address indexed podOwner, bytes delegatePubKey, bytes32 blsPubKeyHash, uint256 validatorIndex
    );

    /**
     * @notice Emitted when an operator is deregistered from the UniFi AVS system.
     * @param operator The address of the deregistered operator.
     */
    event OperatorDeregistered(address indexed operator);

    /**
     * @notice Emitted when a validator is deregistered from the UniFi AVS system.
     * @param blsPubKeyHash The BLS public key hash of the deregistered validator.
     * @param validatorIndex The index of the deregistered validator.
     * @param podOwner The address of the EigenPod owner.
     * @param operator The address of the operator managing the validator.
     */
    event ValidatorDeregistered(bytes32 blsPubKeyHash, uint64 validatorIndex, address podOwner, address operator);

    /**
     * @notice Emitted when an operator's delegate key is set or updated.
     * @param operator The address of the operator.
     * @param newDelegateKey The new delegate key for the operator.
     */
    event OperatorDelegateKeySet(address indexed operator, bytes newDelegateKey);

    /**
     * @notice Registers a new operator in the UniFi AVS system.
     * @param operatorSignature The signature and associated data for operator registration.
     */
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external;

    /**
     * @notice Registers validators for a given pod owner.
     * @param podOwner The address of the pod owner.
     * @param blsPubKeyHashes The BLS public key hashes of the validators to register.
     */
    function registerValidators(address podOwner, bytes32[] calldata blsPubKeyHashes) external;

    /**
     * @notice Deregisters validators from the UniFi AVS system.
     * @param blsPubKeyHashes The BLS public key hashes of the validators to deregister.
     */
    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external;

    /**
     * @notice Deregisters an operator from the UniFi AVS system.
     */
    function deregisterOperator() external;

    /**
     * @notice Retrieves information about a specific operator.
     * @param operator The address of the operator.
     * @return OperatorData struct containing information about the operator.
     */
    function getOperator(address operator) external view returns (OperatorData memory);

    /**
     * @notice Retrieves information about a validator using its BLS public key hash.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @return ValidatorDataExtended struct containing information about the validator.
     */
    function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorDataExtended memory);

    /**
     * @notice Retrieves information about a validator using its validator index.
     * @param validatorIndex The index of the validator.
     * @return ValidatorDataExtended struct containing information about the validator.
     */
    function getValidator(uint256 validatorIndex) external view returns (ValidatorDataExtended memory);

    /**
     * @notice Retrieves information about multiple validators.
     * @param blsPubKeyHashes The BLS public key hashes of the validators.
     * @return An array of ValidatorDataExtended structs containing information about the validators.
     */
    function getValidators(bytes32[] calldata blsPubKeyHashes) external view returns (ValidatorDataExtended[] memory);

    /**
     * @notice Sets the delegate key for an operator.
     * @param newDelegateKey The new delegate key to set.
     */
    function setOperatorDelegateKey(bytes memory newDelegateKey) external;
}

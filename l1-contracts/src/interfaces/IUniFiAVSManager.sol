// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";
import {IBLSApkRegistry} from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import {ISignatureUtils} from "eigenlayer/interfaces/ISignatureUtils.sol";
import "../structs/ValidatorRegistrationParams.sol";
import "../structs/ValidatorData.sol";
import "../structs/OperatorData.sol";
import "../structs/PreConferInfo.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract, which manages operators and validators in the UniFi AVS system.
 * @dev This interface defines the main functions and events for operator and validator management.
 */
interface IUniFiAVSManager {
    /**
     * @notice Thrown when a registration has expired.
     */
    /**
     * @notice Thrown when an invalid registration salt is used.
     */
    /**
     * @notice Thrown when a signature has expired.
     */
    /**
     * @notice Thrown when an invalid operator salt is used.
     */
    /**
     * @notice Thrown when an operator with validators attempts to deregister.
     */
    /**
     * @notice Thrown when a non-operator attempts an operator-only action.
     */
    /**
     * @notice Thrown when an EigenPod does not exist for a given address.
     */
    /**
     * @notice Thrown when an address is not delegated to the expected operator.
     */
    /**
     * @notice Thrown when a validator is not in the active state.
     */
    /**
     * @notice Thrown when a signature is invalid.
     */
    /**
     * @notice Thrown when an operator already exists.
     */
    /**
     * @notice Thrown when an operator is not registered.
     */
    /**
     * @notice Thrown when an operator is already registered.
     */
    /**
     * @notice Thrown when a non-operator attempts to deregister a validator.
     */
    /**
     * @notice Thrown when a validator is already registered.
     */
    /**
     * @notice Thrown when an operator's delegate key is not set.
     */
    error RegistrationExpired();
    error InvalidRegistrationSalt();
    error SignatureExpired();
    error InvalidOperatorSalt();
    error OperatorHasValidators();
    error NotOperator();
    error NoEigenPod();
    error NotDelegatedToOperator();
    error ValidatorNotActive();
    error InvalidSignature();
    error OperatorAlreadyExists();
    error OperatorNotRegistered();
    error OperatorAlreadyRegistered();
    error NotValidatorOperator();
    error ValidatorAlreadyRegistered();
    error DelegateKeyNotSet();

    event OperatorCreated(address indexed operator, address indexed podOwner);
    event OperatorRegistered(address indexed operator);
    event ValidatorDelegateKeyModified(bytes32 indexed blsPubKeyHash, bytes newDelegateKey);
    event ValidatorRegistered(
        address indexed podOwner,
        bytes delegatePubKey,
        bytes32 blsPubKeyHash,
        uint256 validatorIndex
    );
    event OperatorDeregistered(address indexed operator);
    event ValidatorDeregistered(bytes32 blsPubKeyHash, uint64 validatorIndex, address podOwner, address operator);
    event OperatorDelegateKeySet(address indexed operator, bytes newDelegateKey);

    /**
     * @notice Registers a new operator in the UniFi AVS system.
     * @param operatorSignature The signature and associated data for operator registration.
     */
    function registerOperator(
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    /**
     * @notice Registers validators for a given pod owner.
     * @param podOwner The address of the pod owner.
     * @param blsPubKeyHashes The BLS public key hashes of the validators to register.
     */
    function registerValidators(
        address podOwner,
        bytes32[] calldata blsPubKeyHashes
    ) external;

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
    function getOperator(
        address operator
    ) external view returns (OperatorData memory);

    /**
     * @notice Retrieves information about a validator using its BLS public key hash.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @return PreConferInfo struct containing information about the validator.
     */
    function getValidator(bytes32 blsPubKeyHash) external view returns (PreConferInfo memory);

    /**
     * @notice Retrieves information about a validator using its validator index.
     * @param validatorIndex The index of the validator.
     * @return PreConferInfo struct containing information about the validator.
     */
    function getValidator(uint256 validatorIndex) external view returns (PreConferInfo memory);

    /**
     * @notice Retrieves information about multiple validators.
     * @param blsPubKeyHashes The BLS public key hashes of the validators.
     * @return An array of PreConferInfo structs containing information about the validators.
     */
    function getValidators(bytes32[] calldata blsPubKeyHashes) external view returns (PreConferInfo[] memory);

    /**
     * @notice Sets the delegate key for an operator.
     * @param newDelegateKey The new delegate key to set.
     */
    function setOperatorDelegateKey(bytes memory newDelegateKey) external;
}

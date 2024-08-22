// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BN254 } from "eigenlayer-middleware/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import "../structs/ValidatorData.sol";
import "../structs/OperatorData.sol";

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
    error InvalidOperatorSalt();
    error SignatureExpired();
    error OperatorHasValidators();
    error NotOperator();
    error NoEigenPod();
    error DeregistrationDelayNotElapsed();
    error DeregistrationAlreadyStarted();
    error DeregistrationNotStarted();
    error NotDelegatedToOperator();
    error ValidatorNotActive();
    error OperatorAlreadyExists();
    error OperatorNotRegistered();
    error OperatorAlreadyRegistered();
    error NotValidatorOperator();
    error ValidatorAlreadyRegistered();
    error DelegateKeyNotSet();
    error InvalidOperator();
    error NotPodOwner();
    error ValidatorNotFound();
    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error DelegateKeyChangeNotReady();

    /**
     * @notice Emitted when a new operator is registered in the UniFi AVS system.
     * @param operator The address of the registered operator.
     */
    event OperatorRegistered(address indexed operator);

    /**
     * @notice Emitted when a new validator is registered in the UniFi AVS system.
     * @param podOwner The address of the validator's EigenPod owner.
     * @param delegatePubKey The delegate public key for the validator.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @param validatorIndex The beacon chain validator index.
     */
    event ValidatorRegistered(
        address indexed podOwner, address indexed operator, bytes delegatePubKey, bytes32 blsPubKeyHash, uint256 validatorIndex
    );

    /**
     * @notice Emitted when an operator starts the deregistration process.
     * @param operator The address of the operator starting deregistration.
     */
    event OperatorDeregisterStarted(address indexed operator);

    /**
     * @notice Emitted when an operator is deregistered from the UniFi AVS system.
     * @param operator The address of the deregistered operator.
     */
    event OperatorDeregistered(address indexed operator);

    /**
     * @notice Emitted when a validator is deregistered from the UniFi AVS system.
     * @param podOwner The address of the EigenPod owner.
     * @param operator The address of the operator managing the validator.
     * @param delegatePubKey The delegate public key for the validator.
     * @param blsPubKeyHash The BLS public key hash of the deregistered validator.
     * @param validatorIndex The index of the deregistered validator.
     */
    event ValidatorDeregistered(
        address indexed podOwner, address indexed operator, bytes delegatePubKey, bytes32 blsPubKeyHash, uint256 validatorIndex
    );

    /**
     * @notice Emitted when an operator's delegate key is set or updated.
     * @param operator The address of the operator.
     * @param oldDelegateKey The previous delegate key for the operator.
     * @param newDelegateKey The new delegate key for the operator.
     */
    event OperatorDelegateKeySet(address indexed operator, bytes oldDelegateKey, bytes newDelegateKey);
    event OperatorDelegateKeyChangeInitiated(address indexed operator, bytes oldDelegateKey, bytes newDelegateKey, uint256 validAfter);

    /**
     * @notice Emitted when the deregistration delay is updated.
     * @param oldDelay The previous deregistration delay value.
     * @param newDelay The new deregistration delay value.
     */
    event DeregistrationDelaySet(uint64 oldDelay, uint64 newDelay);

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
     * @notice Starts the process of deregistering an operator from the UniFi AVS system.
     */
    function startDeregisterOperator() external;

    /**
     * @notice Finishes the process of deregistering an operator from the UniFi AVS system.
     */
    function finishDeregisterOperator() external;

    /**
     * @notice Retrieves information about a specific operator.
     * @param operator The address of the operator.
     * @return OperatorDataExtended struct containing information about the operator.
     */
    function getOperator(address operator) external view returns (OperatorDataExtended memory);

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

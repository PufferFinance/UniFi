// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import { IAVSDirectoryExtended } from "../interfaces/EigenLayer/IAVSDirectoryExtended.sol";
import "../structs/ValidatorData.sol";
import "../structs/OperatorData.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract, which manages operators and validators in the UniFi AVS system.
 * @dev This interface defines the main functions and events for operator and validator management.
 */
interface IUniFiAVSManager {
    /// @notice Thrown when an operator attempts to deregister while still having validators
    error OperatorHasValidators();

    /// @notice Thrown when a non-operator attempts an operator-only action
    error NotOperator();

    /// @notice Thrown when an EigenPod does not exist for a given address
    error NoEigenPod();

    /// @notice Thrown when trying to finish deregistering an operator before the delay has elapsed
    error DeregistrationDelayNotElapsed();

    /// @notice Thrown when attempting to start deregistration for an operator that has already started
    error DeregistrationAlreadyStarted();

    /// @notice Thrown when trying to finish deregistration for an operator that hasn't started
    error DeregistrationNotStarted();

    /// @notice Thrown when an address is not delegated to the expected operator
    error NotDelegatedToOperator();

    /// @notice Thrown when a validator is not in the active state
    error ValidatorNotActive();

    /// @notice Thrown when an action requires a registered operator, but the operator is not registered
    error OperatorNotRegistered();

    /// @notice Thrown when attempting to register an operator that is already registered
    error OperatorAlreadyRegistered();

    /// @notice Thrown when a non-operator attempts to deregister a validator
    error NotValidatorOperator();

    /// @notice Thrown when attempting to register a validator that is already registered
    error ValidatorAlreadyRegistered();

    /// @notice Thrown when an operator's delegate key is not set
    error DelegateKeyNotSet();

    /// @notice Thrown when a validator cannot be found
    error ValidatorNotFound();

    /// @notice Thrown when an unauthorized action is attempted
    error Unauthorized();

    /// @notice Thrown when trying to update an operator commitment before the change delay has passed
    error CommitmentChangeNotReady();

    /// @notice Thrown when an index is out of bounds
    error IndexOutOfBounds();

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
        address indexed podOwner,
        address indexed operator,
        bytes delegatePubKey,
        bytes32 blsPubKeyHash,
        uint256 validatorIndex
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
        address indexed podOwner,
        address indexed operator,
        bytes delegatePubKey,
        bytes32 blsPubKeyHash,
        uint256 validatorIndex
    );

    /**
     * @notice Emitted when an operator's commitment is set or updated.
     * @param operator The address of the operator.
     * @param oldCommitment The previous commitment for the operator.
     * @param newCommitment The new commitment for the operator.
     */
    event OperatorCommitmentSet(
        address indexed operator, OperatorCommitment oldCommitment, OperatorCommitment newCommitment
    );

    event OperatorCommitmentChangeInitiated(
        address indexed operator, OperatorCommitment oldCommitment, OperatorCommitment newCommitment, uint128 validAfter
    );

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
     * @notice Sets the commitment for an operator.
     * @param newCommitment The new commitment to set.
     */
    function setOperatorCommitment(OperatorCommitment memory newCommitment) external;

    /**
     * @notice Updates the operator's commitment after the delay period.
     */
    function updateOperatorCommitment() external;

    /**
     * @notice Checks if a validator is registered for a specific chain ID.
     * @param blsPubKeyHash The BLS public key hash of the validator.
     * @param chainId The chain ID to check.
     * @return bool True if the validator is registered for the given chain ID, false otherwise.
     */
    function isValidatorInChainId(bytes32 blsPubKeyHash, uint256 chainId) external view returns (bool);

    /**
     * @notice Returns the EigenPodManager contract.
     * @return IEigenPodManager The EigenPodManager contract.
     */
    function EIGEN_POD_MANAGER() external view returns (IEigenPodManager);

    /**
     * @notice Returns the EigenDelegationManager contract.
     * @return IDelegationManager The EigenDelegationManager contract.
     */
    function EIGEN_DELEGATION_MANAGER() external view returns (IDelegationManager);

    /**
     * @notice Returns the AVSDirectoryExtended contract.
     * @return IAVSDirectoryExtended The AVSDirectoryExtended contract.
     */
    function AVS_DIRECTORY() external view returns (IAVSDirectoryExtended);
}

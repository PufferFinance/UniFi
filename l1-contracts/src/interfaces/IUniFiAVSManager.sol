// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";
import {IBLSApkRegistry} from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import {ISignatureUtils} from "eigenlayer/interfaces/ISignatureUtils.sol";
import "../structs/ValidatorRegistrationParams.sol";
import "../structs/ValidatorData.sol";
import "../structs/OperatorData.sol";

/**
 * @title IUniFiAVSManager
 * @notice Interface for the UniFiAVSManager contract.
 */
interface IUniFiAVSManager {
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

    function registerOperator(
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function registerValidators(
        address podOwner,
        bytes32[] calldata blsPubKeyHashes
    ) external;

    function deregisterValidators(bytes32[] calldata blsPubKeyHashes) external;

    function deregisterOperator() external;

    function getOperator(
        address operator
    ) external view returns (OperatorData memory);

    function isDelegatedPodOwner(
        address operator,
        address podOwner
    ) external view returns (bool);

    function setOperatorDelegateKey(bytes memory newDelegateKey) external;
}

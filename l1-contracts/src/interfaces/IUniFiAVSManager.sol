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
    error OperatorHasValidators();
    error NotOperator();
    error NoEigenPod();
    error NotDelegatedToOperator();
    error ValidatorNotActive();
    error InvalidSignature();
    error OperatorAlreadyExists();

    event OperatorCreated(address indexed operator, address indexed podOwner);
    event OperatorRegistered(
        address indexed operator,
        address indexed podOwner
    );
    event ValidatorRegistered(
        address indexed podOwner,
        bytes32 indexed ecdsaPubKeyHash,
        bytes32 blsPubKeyHash
    );
    event OperatorDeregistered(address indexed operator);
    event ValidatorDeregistered(bytes32 blsPubKeyHash);

    function registerOperator(
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function registerValidator(
        address podOwner,
        ValidatorRegistrationParams calldata params
    ) external;

    function deregisterValidator(bytes32[] calldata blsPubKeyHashs) external;

    function deregisterOperator() external;

    function getValidator(
        bytes32 blsPubKeyHash
    ) external view returns (ValidatorData memory);

    function getValidator(
        uint256 validatorIndex
    ) external view returns (ValidatorData memory);

    function getOperator(
        address operator
    ) external view returns (OperatorData memory);
}

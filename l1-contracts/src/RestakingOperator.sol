// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { ISlasher } from "eigenlayer/interfaces/ISlasher.sol";
import { IRestakingOperator } from "./interfaces/IRestakingOperator.sol";
import { Unauthorized, InvalidAddress } from "./Errors.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer/interfaces/ISignatureUtils.sol";
import { IUniFiAVSManager } from "./interfaces/IUniFiAVSManager.sol";
import { IRewardsCoordinator } from "./interfaces/EigenLayer/IRewardsCoordinator.sol";

/**
 * @title RestakingOperator
 * @author Puffer Finance
 * @notice PufferModule
 * @custom:security-contact security@puffer.fi
 */
contract RestakingOperator is IRestakingOperator, IERC1271, Initializable, AccessManagedUpgradeable {
    using Address for address;
    // keccak256(abi.encode(uint256(keccak256("RestakingOperator.storage")) - 1)) & ~bytes32(uint256(0xff))
    // slither-disable-next-line unused-state

    /**
     * @dev Upgradeable contract from EigenLayer
     */
    IRewardsCoordinator public immutable EIGEN_REWARDS_COORDINATOR;

    bytes32 private constant _RESTAKING_OPERATOR_STORAGE =
        0x2182a68f8e463a6b4c76f5de5bb25b7b51ccc88cb3b9ba6c251c356b50555100;

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant _EIP1271_MAGIC_VALUE = 0x1626ba7e;
    // Invalid signature value (EIP-1271)
    bytes4 internal constant _EIP1271_INVALID_VALUE = 0xffffffff;

    /**
     * @custom:storage-location erc7201:RestakingOperator.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    struct RestakingOperatorStorage {
        mapping(bytes32 digestHash => address signer) hashSigners;
    }

    /**
     * @dev Upgradeable contract from EigenLayer
     */
    IDelegationManager public immutable override EIGEN_DELEGATION_MANAGER;

    /**
     * @dev Upgradeable contract from EigenLayer
     */
    ISlasher public immutable override EIGEN_SLASHER;

    // We use constructor to set the immutable variables
    constructor(
        IDelegationManager delegationManager,
        ISlasher slasher,
        IRewardsCoordinator rewardsCoordinator
    ) {
        if (address(delegationManager) == address(0)) {
            revert InvalidAddress();
        }
        if (address(slasher) == address(0)) {
            revert InvalidAddress();
        }
        EIGEN_DELEGATION_MANAGER = delegationManager;
        EIGEN_SLASHER = slasher;
        EIGEN_REWARDS_COORDINATOR = rewardsCoordinator;
        _disableInitializers();
    }

    function initialize(
        address initialAuthority,
        IDelegationManager.OperatorDetails calldata operatorDetails,
        string calldata metadataURI
    ) external initializer {
        __AccessManaged_init(initialAuthority);
        EIGEN_DELEGATION_MANAGER.registerAsOperator(operatorDetails, metadataURI);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function optIntoSlashing(address slasher) external virtual {
        EIGEN_SLASHER.optIntoSlashing(slasher);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function modifyOperatorDetails(IDelegationManager.OperatorDetails calldata newOperatorDetails)
        external
        virtual
    {
        EIGEN_DELEGATION_MANAGER.modifyOperatorDetails(newOperatorDetails);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function updateOperatorMetadataURI(string calldata metadataURI) external virtual {
        EIGEN_DELEGATION_MANAGER.updateOperatorMetadataURI(metadataURI);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function updateSignatureProof(bytes32 digestHash, address signer) external virtual {
        RestakingOperatorStorage storage $ = _getRestakingOperatorStorage();

        $.hashSigners[digestHash] = signer;
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function registerOperatorToAVS(
        address avsManager,
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external virtual {
        IUniFiAVSManager(avsManager).registerOperatorToAVS(
            quorumNumbers,
            socket,
            params,
            operatorSignature
        );
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function customCalldataCall(address target, bytes calldata customCalldata)
        external
        virtual
        returns (bytes memory response)
    {
        return target.functionCall(customCalldata);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function deregisterOperatorFromAVS(address avsManager, bytes calldata quorumNumbers)
        external
        virtual
    {
        IUniFiAVSManager(avsManager).deregisterOperatorFromAVS(quorumNumbers);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to the PufferModuleManager
     */
    function updateOperatorAVSSocket(address avsManager, string memory socket)
        external
        virtual
    {
        IUniFiAVSManager(avsManager).updateOperatorAVSSocket(socket);
    }

    /**
     * @inheritdoc IRestakingOperator
     * @dev Restricted to PufferModuleManager
     */
    function callSetClaimerFor(address claimer) external virtual {
        EIGEN_REWARDS_COORDINATOR.setClaimerFor(claimer);
    }

    /**
     * @notice Verifies that the signer is the owner of the signing contract.
     */
    function isValidSignature(bytes32 digestHash, bytes calldata signature) external view override returns (bytes4) {
        RestakingOperatorStorage storage $ = _getRestakingOperatorStorage();

        address signer = $.hashSigners[digestHash];

        // Validate signatures
        if (signer != address(0) && ECDSA.recover(digestHash, signature) == signer) {
            return _EIP1271_MAGIC_VALUE;
        } else {
            return _EIP1271_INVALID_VALUE;
        }
    }

    function _getRestakingOperatorStorage() internal pure returns (RestakingOperatorStorage storage $) {
        // solhint-disable-next-line
        assembly {
            $.slot := _RESTAKING_OPERATOR_STORAGE
        }
    }
}

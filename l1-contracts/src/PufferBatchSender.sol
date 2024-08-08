// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BeaconChainHelperLib } from "./BeaconChainHelperLib.sol";
import { PufferBatchSenderStorage } from "./PufferBatchSenderStorage.sol";
import { IPufferBatchSender } from "./interfaces/IPufferBatchSender.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title PufferBatchSender
 * @dev Main contract for managing batch operations and validator allowlisting.
 */
contract PufferBatchSender is
    PufferBatchSenderStorage,
    UUPSUpgradeable,
    AccessManagedUpgradeable,
    IPufferBatchSender
{
    using Address for address payable;

    uint128 public immutable BOND_AMOUNT;
    address public immutable PUFFER_PROTOCOL;
    address public immutable PUFFER_BATCH_INBOX;

    /**
     * @notice Constructor to initialize the contract with protocol address and bond amount.
     * @param pufferProtocol The address of the Puffer protocol.
     * @param bondAmount The amount of bond required.
     */
    constructor(address pufferProtocol, address batchInbox, uint128 bondAmount) {
        PUFFER_PROTOCOL = pufferProtocol;
        PUFFER_BATCH_INBOX = batchInbox;
        BOND_AMOUNT = bondAmount;
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
    }

    /**
     * @notice Get validator details.
     * @param index The index of the validator.
     * @return The validator struct.
     */
    function getValidator(uint256 index) external view returns (Validator memory) {
        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        return $.validators[index];
    }

    function getBatchByUserAndTimestamp(uint256 timestamp, address sender)
        external
        view
        returns (BatchMetadata memory)
    {
        bytes32 batchHash = keccak256(abi.encode(sender, timestamp));

        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        return $.batches[batchHash];
    }

    /**
     * @notice Get batch metadata.
     * @param batchHash The hash of the batch.
     * @return The batch metadata struct.
     */
    function getBatch(bytes32 batchHash) external view returns (BatchMetadata memory) {
        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        return $.batches[batchHash];
    }

    /**
     * @notice Allowlist a set of validators.
     * @param indexes The indexes of the validators to allowlist.
     */
    function allowlistValidators(uint256[] calldata indexes) external override {
        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        for (uint256 i = 0; i < indexes.length; i++) {
            $.validators[indexes[i]] = Validator({ isAllowlisted: true });
        }
    }

    /**
     * @notice Publish a blob batch.
     */
    function publishBatch() external payable override {
        if (msg.value != BOND_AMOUNT) {
            revert IncorrectBondAmount();
        }

        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        bytes32 batchHash = keccak256(abi.encode(msg.sender, block.timestamp));

        // only one batch allowed per sender per block
        if ($.batches[batchHash].bond != 0) {
            revert BatchAlreadyExist();
        }

        $.batches[batchHash] = BatchMetadata({ bond: uint128(msg.value), bondDispersed: false });

        (bool success,) = PUFFER_BATCH_INBOX.call("");

        if (!success) {
            revert BatchInboxReverted();
        }
    }

    /**
     * @notice Return bond to the sender if the block proposer is an allowlisted one.
     * @param timestamp The timestamp of the block/batch.
     * @param sender The sender of the blob batch.
     * @param proposerIndex The index of the proposer/validator.
     * @param proof The proof for verifying the proposerIndex using beacon state root.
     */
    function returnBond(uint256 timestamp, address sender, uint256 proposerIndex, bytes32[2] memory proof)
        external
        override
    {
        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        bytes32 batchHash = keccak256(abi.encode(sender, timestamp));

        BatchMetadata memory batch = $.batches[batchHash];
        if (batch.bond == 0) {
            revert BatchDoesNotExist();
        }
        if (batch.bondDispersed) {
            revert BondAlreadyDispersed();
        }
        if (!$.validators[proposerIndex].isAllowlisted) {
            revert NotAllowlisted();
        }

        if (!BeaconChainHelperLib.verifyProposerAt(timestamp, proposerIndex, proof)) {
            revert InvalidProof();
        }

        $.batches[batchHash].bondDispersed = true;

        payable(sender).sendValue(batch.bond);
    }

    /**
     * @notice Distribute bond between the sender and protocol if the block proposer is not an allowlisted one.
     * @param timestamp The timestamp of the block/batch.
     * @param sender The sender of the blob batch.
     * @param proposerIndex The index of the proposer/validator.
     * @param proof The proof for verifying the proposerIndex using beacon state root.
     */
    function distributeBond(uint256 timestamp, address sender, uint256 proposerIndex, bytes32[2] memory proof)
        external
        override
    {
        BatchSenderStorage storage $ = _getPufferBatchSenderStorage();
        bytes32 batchHash = keccak256(abi.encode(sender, timestamp));

        BatchMetadata memory batch = $.batches[batchHash];
        if (batch.bond == 0) {
            revert BatchDoesNotExist();
        }
        if (batch.bondDispersed) {
            revert BondAlreadyDispersed();
        }
        if ($.validators[proposerIndex].isAllowlisted) {
            revert NotAllowlisted();
        }

        if (!BeaconChainHelperLib.verifyProposerAt(timestamp, proposerIndex, proof)) {
            revert InvalidProof();
        }

        $.batches[batchHash].bondDispersed = true;

        uint256 halfBond = batch.bond / 2;
        payable(msg.sender).sendValue(halfBond);
        payable(PUFFER_PROTOCOL).sendValue(batch.bond - halfBond);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title PufferBatchInboxStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract PufferBatchInboxStorage {
    struct Validator {
        bool isAllowlisted;
    }

    struct BatchMetadata {
        bool bondDispersed;
        uint128 bond;
    }

    struct BatchInboxStorage {
        mapping(uint256 => Validator) validators;
        mapping(bytes32 => BatchMetadata) batches;
    }

    /**
     * @dev Storage slot location for PufferBatchInbox
     * @custom:storage-location erc7201:PufferBatchInbox.storage
     */
    bytes32 private constant _STORAGE_LOCATION = 0xfee41a6d2b86b757dd00cd2166d8727686a349977cbc2b6b6a2ca1c3e7215000;

    function _getPufferBatchInboxStorage() internal pure returns (BatchInboxStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}

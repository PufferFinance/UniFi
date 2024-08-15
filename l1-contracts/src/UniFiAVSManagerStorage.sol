// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./structs/ValidatorData.sol";
import "./structs/OperatorData.sol";

/**
 * @title UniFiAVSManagerStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract UniFiAVSManagerStorage {
    struct UniFiAVSStorage {
        mapping(bytes32 => ValidatorData) validators;
        mapping(uint256 => bytes32) validatorIndexes;
        mapping(address => OperatorData) operators; // podOwner => OperatorData
        mapping(bytes32 => bool) validatorSalts;
        mapping(bytes32 => bool) operatorSalts;
    }

    /**
     * @dev Storage slot location for UniFiAVSManager
     * @custom:storage-location erc7201:UniFiAVSManager.storage
     */
    bytes32 private constant _STORAGE_LOCATION = 0xfee41a6d2b86b757dd00cd2166d8727686a349977cbc2b6b6a2ca1c3e7215000;

    function _getUniFiAVSManagerStorage() internal pure returns (UniFiAVSStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}

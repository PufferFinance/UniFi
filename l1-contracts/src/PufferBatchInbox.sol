// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

contract PufferBatchInbox is UUPSUpgradeable, AccessManagedUpgradeable {
    constructor() {
        _disableInitializers();
    }

    receive() external payable { }

    fallback() external payable { }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

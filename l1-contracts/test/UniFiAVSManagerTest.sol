// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../src/UniFiAVSManager.sol";

contract UniFiAVSManagerTest is UniFiAVSManager {
    constructor(
        IEigenPodManager eigenPodManager,
        IDelegationManager eigenDelegationManager,
        IAVSDirectory avsDirectory
    ) UniFiAVSManager(eigenPodManager, eigenDelegationManager, avsDirectory) {}

    function _authorizeUpgrade(address newImplementation) internal override {}
}

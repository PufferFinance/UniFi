// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BaseScript } from "script/BaseScript.s.sol";
import { UniFiAVSManager } from "../src/UniFiAVSManager.sol";
import { IEigenPodManager } from "eigenlayer/interfaces/IEigenPodManager.sol";
import { IDelegationManager } from "eigenlayer/interfaces/IDelegationManager.sol";
import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";

contract DeployAVSManager is BaseScript {
    function run(
        address accessManager,
        address eigenPodManager,
        address eigenDelegationManager,
        address avsDirectory
    ) public broadcast returns (address) {
        UniFiAVSManager avsManager = new UniFiAVSManager(
            IEigenPodManager(eigenPodManager),
            IDelegationManager(eigenDelegationManager),
            IAVSDirectory(avsDirectory)
        );

        // Initialize the contract
        avsManager.initialize(accessManager);

        return address(avsManager);
    }
}

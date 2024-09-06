// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BaseScript } from "./BaseScript.s.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { DeployEverything } from "./DeployEverything.s.sol";
import { console } from "forge-std/console.sol";

contract DeployUnifiToHolesky is BaseScript {
    function run() public returns (address) {
        vm.startBroadcast(_deployerPrivateKey);
        // Deploy AccessManager
        AccessManager accessManager = new AccessManager(_broadcaster);
        vm.stopBroadcast();

        console.log("broadcaster", _broadcaster);
        console.log("AccessManager deployed at:", address(accessManager));

        // Set addresses for EigenLayer contracts
        address eigenPodManager = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        address eigenDelegationManager = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
        address avsDirectory = 0x135DDa560e946695d6f155dACaFC6f1F25C1F5AF;

        console.log("EigenPodManager address:", eigenPodManager);
        console.log("EigenDelegationManager address:", eigenDelegationManager);
        console.log("AVSDirectory address:", avsDirectory);

        // Deploy everything else
        DeployEverything deployEverything = new DeployEverything();
        deployEverything.run(address(accessManager), eigenPodManager, eigenDelegationManager, avsDirectory);

        return address(accessManager);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BaseScript } from "script/BaseScript.s.sol";
import { DeployAVS } from "script/DeployAVS.s.sol";
import { SetupAccess } from "script/SetupAccess.s.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

/**
 * @title Deploy all protocol contracts
 * @author Puffer Finance
 * @notice Deploys all contracts for the AVS and sets up the access control
 * @dev Example on how to run the script
 *      forge script script/DeployEverything.s.sol:DeployEverything --rpc-url=$RPC_URL --sig 'run()' --broadcast
 */
contract DeployEverything is BaseScript {
    address DAO;

    function run(
        address accessManager,
        address eigenPodManager,
        address eigenDelegationManager,
        address avsDirectory
    ) public returns (AVSDeployment memory) {
        AVSDeployment memory deployment;

        // 1. Deploy AVSManager
        address avsManager = new DeployAVSManager().run(
            accessManager,
            eigenPodManager,
            eigenDelegationManager,
            avsDirectory
        );

        deployment.avsManagerImplementation = avsManager;
        // todo access manager
        // deployment.accessManager = avsDeployment.accessManager;

        // `anvil` in the terminal
        if (_localAnvil) {
            DAO = _broadcaster;
        } else if (isAnvil()) {
            // Tests environment `forge test ...`
            DAO = makeAddr("DAO");
        } else {
            // Testnet deployments
            DAO = _broadcaster;
        }

        new SetupAccess().run(avsDeployment, DAO, _broadcaster);

        _writeJson(avsDeployment);

        return avsDeployment;
    }

    function _writeJson(AVSDeployment memory deployment) internal {
        string memory obj = "";

        vm.serializeAddress(obj, "avsManagerImplementation", deployment.avsManagerImplementation);
        vm.serializeAddress(obj, "avsManager", deployment.avsManager);
        vm.serializeAddress(obj, "dao", DAO);
        vm.serializeAddress(obj, "accessManager", deployment.accessManager);

        string memory finalJson = vm.serializeString(obj, "", "");
        vm.writeJson(finalJson, "./output/avsDeployment.json");
    }
}

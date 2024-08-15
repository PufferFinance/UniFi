// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BaseScript } from "script/BaseScript.s.sol";
import { GuardianModule } from "../src/GuardianModule.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { PufferOracleV2 } from "../src/PufferOracleV2.sol";

// forge script script/DeployPufferOracle.s.sol:DeployPufferOracle --rpc-url=$EPHEMERY_RPC_URL --sig 'run(address[] calldata, uint256)' "[0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0]" 1
contract DeployAVSManager is BaseScript {
    function run(address accessManager, address eigenPodManager, address eigenDelegationManager, address avsDirectory)
        public
        broadcast
        returns (address)
    {
        UniFiAVSManager avsManager =
            new UniFiAVSManager(...)

        // Initialize the contract

        return address(avsManager);
    }
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PufferBatchInbox } from "../src/PufferBatchInbox.sol";

/**
 * // Check that the simulation
 * add --slow if deploying to a mainnet fork like tenderly (its buggy sometimes)
 *
 *       forge script script/DeployBatchInbox.s.sol:DeployBatchInbox --rpc-url $RPC_URL --account puffer
 *
 *       forge cache clean
 *
 *       forge script script/DeployBatchInbox.s.sol:DeployBatchInbox --rpc-url $RPC_URL --account puffer --broadcast
 */
contract DeployBatchInbox is Script {
    address PROTOCOL_TREASURY = 0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0;
    AccessManager accessManager;

    function run() public {
        vm.startBroadcast();

        accessManager = new AccessManager(PROTOCOL_TREASURY);

        PufferBatchInbox impl = new PufferBatchInbox(PROTOCOL_TREASURY, 0.01 ether);

        PufferBatchInbox inboxProxy = PufferBatchInbox(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(PufferBatchInbox.initialize, (address(accessManager))))
            )
        );

        console.log("PufferBatchInbox Proxy:", address(inboxProxy));
        console.log("PufferBatchInbox Implementation:", address(impl));
    }
}

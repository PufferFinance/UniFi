// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PufferBatchSender } from "../src/PufferBatchSender.sol";
import { PufferBatchInbox } from "../src/PufferBatchInbox.sol";
/**
 * // Check that the simulation
 * add --slow if deploying to a mainnet fork like tenderly (its buggy sometimes)
 *
 *       forge script script/DeployBatchSender.s.sol:DeployBatchSender --rpc-url $RPC_URL --account puffer
 *
 *       forge cache clean
 *
 *       forge script script/DeployBatchSender.s.sol:DeployBatchSender --rpc-url $RPC_URL --account puffer --broadcast
 */

contract DeployBatchSender is Script {
    address PROTOCOL_TREASURY = 0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0;
    AccessManager accessManager;

    function run() public {
        vm.startBroadcast();

        accessManager = new AccessManager(PROTOCOL_TREASURY);

        PufferBatchInbox inboxImpl = new PufferBatchInbox();

        PufferBatchInbox inboxProxy = PufferBatchInbox(
            payable(
                address(
                    new ERC1967Proxy(
                        address(inboxImpl), abi.encodeCall(PufferBatchInbox.initialize, (address(accessManager)))
                    )
                )
            )
        );

        PufferBatchSender senderImpl = new PufferBatchSender(PROTOCOL_TREASURY, address(inboxProxy), 0.01 ether);

        PufferBatchSender senderProxy = PufferBatchSender(
            address(
                new ERC1967Proxy(
                    address(senderImpl), abi.encodeCall(PufferBatchSender.initialize, (address(accessManager)))
                )
            )
        );

        console.log("PufferBatchSender Proxy:", address(senderProxy));
        console.log("PufferBatchSender Implementation:", address(senderImpl));

        console.log("PufferBatchInbox Proxy:", address(inboxProxy));
        console.log("PufferBatchInbox Implementation:", address(inboxImpl));
    }
}

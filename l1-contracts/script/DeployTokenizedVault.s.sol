// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {TokenizedVault} from "../src/TokenizedVault.sol";

/**
 * // Check that the simulation
 * add --slow if deploying to a mainnet fork like tenderly (it's buggy sometimes)
 *
 *       forge script script/DeployTokenizedVault.s.sol:DeployTokenizedVault --rpc-url $RPC_URL --account puffer
 *
 *       forge cache clean
 *
 *       forge script script/DeployTokenizedVault.s.sol:DeployTokenizedVault --rpc-url $RPC_URL --account puffer --broadcast
 */

contract DeployTokenizedVault is Script {
    address UNDERLYING_TOKEN = 0xd98B590ebE0a3eD8C144170bA4122D402182976f; // Address of the underlying ERC20 token
    address L1_STANDARD_BRIDGE = 0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1; //SEPOLIA // Address of the L1StandardBridge
    address BASED_APP_CHAIN = 0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0; // DUMMY address for now // Address of the BasedAppChain

    function run() public {
        vm.startBroadcast();

        ERC20 underlying = ERC20(UNDERLYING_TOKEN);

        TokenizedVault vault = new TokenizedVault(
            underlying,
            "uniFi ETH",
            "unifiETH",
            L1_STANDARD_BRIDGE,
            BASED_APP_CHAIN
        );

        console.log("TokenizedVault deployed at:", address(vault));

        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { UniFiAVSManager } from "../src/UniFiAVSManager.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Multicall } from "@openzeppelin/contracts/utils/Multicall.sol";
import { console } from "forge-std/console.sol";
import { PUBLIC_ROLE, ROLE_ID_DAO, ROLE_ID_PUFFER_PROTOCOL, ROLE_ID_OPERATIONS_MULTISIG } from "./Roles.sol";

/**
 * @title GenerateAccessManagerCallData
 * @author Puffer Finance
 * @notice Generates the AccessManager call data to setup the public access
 * The returned calldata is queued and executed by the Operations Multisig
 * 1. timelock.queueTransaction(address(accessManager), encodedMulticall, 1)
 * 2. ... 7 days later ...
 * 3. timelock.executeTransaction(address(accessManager), encodedMulticall, 1)
 */
contract GenerateAccessManagerCallData is Script {
    function run(address avsManagerProxy) public pure returns (bytes memory) {
        bytes[] memory calldatas = new bytes[](3);

        // Combine the two calldatas
        calldatas[0] = _getPublicSelectorsCalldata({ avsManagerProxy: avsManagerProxy });
        calldatas[1] = _getDaoSelectorsCalldataCalldata({ avsManagerProxy: avsManagerProxy });
        calldatas[2] = _getOperationsSelectorsCalldata({ avsManagerProxy: avsManagerProxy });

        bytes memory encodedMulticall = abi.encodeCall(Multicall.multicall, (calldatas));

        // console.log("GenerateAccessManagerCallData:");
        // console.logBytes(encodedMulticall);

        return encodedMulticall;
    }

    function _getPublicSelectorsCalldata(address avsManagerProxy) internal pure returns (bytes memory) {
        // Public selectors for AVSManager
        bytes4[] memory publicSelectors = new bytes4[](0);
        // bytes4[] memory publicSelectors = new bytes4[](4);
        // publicSelectors[0] = UniFiAVSManager.withdraw.selector;
        // publicSelectors[1] = UniFiAVSManager.redeem.selector;
        // publicSelectors[2] = UniFiAVSManager.depositETH.selector;
        // publicSelectors[3] = UniFiAVSManager.depositStETH.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, avsManagerProxy, publicSelectors, PUBLIC_ROLE
        );
    }

    function _getDaoSelectorsCalldataCalldata(address avsManagerProxy) internal pure returns (bytes memory) {
        // DAO selectors
        bytes4[] memory daoSelectors = new bytes4[](0);
        // bytes4[] memory daoSelectors = new bytes4[](1);
        // daoSelectors[0] = UniFiAVSManager.setDailyWithdrawalLimit.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, avsManagerProxy, daoSelectors, ROLE_ID_DAO
        );
    }

    function _getOperationsSelectorsCalldata(address avsManagerProxy) internal pure returns (bytes memory) {
        // Operations multisig
        bytes4[] memory operationsSelectors = new bytes4[](0);
        // bytes4[] memory operationsSelectors = new bytes4[](3);
        // operationsSelectors[0] = UniFiAVSManager.initiateETHWithdrawalsFromLido.selector;
        // operationsSelectors[1] = UniFiAVSManager.claimWithdrawalsFromLido.selector;
        // operationsSelectors[2] = UniFiAVSManager.claimWithdrawalFromEigenLayerM2.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            avsManagerProxy,
            operationsSelectors,
            ROLE_ID_OPERATIONS_MULTISIG
        );
    }
}

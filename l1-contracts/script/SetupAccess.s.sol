// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {UniFiAVSManager} from "../src/UniFiAVSManager.sol";
import {GenerateAccessManagerCallData} from "../script/GenerateAccessManagerCallData.sol";
import {AVSDeployment} from "script/DeploymentStructs.sol";

import {ROLE_ID_OPERATIONS_MULTISIG, ROLE_ID_OPERATIONS_PAYMASTER, ROLE_ID_PUFFER_PROTOCOL, ROLE_ID_DAO, ROLE_ID_OPERATIONS_COORDINATOR, ROLE_ID_VT_PRICER} from "../script/Roles.sol";

contract SetupAccess is BaseScript {
    AccessManager internal accessManager;

    AVSDeployment internal avsDeployment;

    function run(
        AVSDeployment memory deployment,
        address DAO
    ) external broadcast {
        avsDeployment = deployment;
        accessManager = AccessManager(payable(deployment.accessManager));

        // We do one multicall to setup everything
        bytes[] memory calldatas = _generateAccessCalldata({
            rolesCalldatas: _grantRoles(DAO),
            uniFiAVSManagerRoles: _setupUniFiAVSManagerRoles(),
            uniFiAVSManagerAccess: _setupUniFiAVSManagerAccess(),
            roleLabels: _labelRoles()
        });

        bytes memory multicallData = abi.encodeCall(
            Multicall.multicall,
            (calldatas)
        );
        console.logBytes(multicallData);
        (bool s, ) = address(accessManager).call(multicallData);
        require(s, "failed setupAccess GenerateAccessManagerCallData 1");

        // This will be executed by the operations multisig on mainnet
        bytes memory cd = new GenerateAccessManagerCallData().run(
            deployment.avsManagerProxy
        );
        console.logBytes(cd);

        (s, ) = address(accessManager).call(cd);
        require(s, "failed setupAccess GenerateAccessManagerCallData");
    }

    function _generateAccessCalldata(
        bytes[] memory rolesCalldatas,
        bytes[] memory uniFiAVSManagerRoles,
        bytes[] memory uniFiAVSManagerAccess,
        bytes[] memory roleLabels
    ) internal view returns (bytes[] memory calldatas) {
        calldatas = new bytes[](32);
        calldatas[0] = rolesCalldatas[0];

        calldatas[1] = uniFiAVSManagerRoles[0];
        calldatas[2] = uniFiAVSManagerRoles[1];

        calldatas[3] = uniFiAVSManagerAccess[0];
        calldatas[4] = uniFiAVSManagerAccess[1];
        calldatas[5] = uniFiAVSManagerAccess[2];

        calldatas[6] = roleLabels[0];
    }

    function _grantRoles(address DAO) internal view returns (bytes[] memory) {
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.grantRole.selector,
            ROLE_ID_DAO,
            DAO,
            0
        );

        return calldatas;
    }

    function _labelRoles() internal pure returns (bytes[] memory) {
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.labelRole.selector,
            ROLE_ID_DAO,
            "Puffer DAO"
        );

        return calldatas;
    }

    function _setupUniFiAVSManagerRoles()
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory calldatas = new bytes[](2);

        bytes4[] memory daoSelectors = new bytes4[](0);
        // daoSelectors[0] = UniFiAVSManager.TODO.selector;

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
        address(avsDeployment.avsManagerProxy),
            daoSelectors,
            ROLE_ID_DAO
        );

        bytes4[] memory publicSelectors = new bytes4[](0);
        // publicSelectors[0] = UniFiAVSManager.TODO.selector;

        calldatas[1] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            address(avsDeployment.avsManagerProxy),
            publicSelectors,
            accessManager.PUBLIC_ROLE()
        );

        return calldatas;
    }

    function _setupUniFiAVSManagerAccess()
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory calldatas = new bytes[](3);

        // Dao selectors
        bytes4[] memory daoSelectors = new bytes4[](0); // todo
        // daoSelectors[0] = UniFiAVSManager.TODO.selector;

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            avsDeployment.avsManagerProxy,
            daoSelectors,
            ROLE_ID_DAO
        );

        // Operations selectors
        bytes4[] memory operationsSelectors = new bytes4[](0);
        // operationsSelectors[0] = UniFiAVSManager.TODO.selector;

        calldatas[1] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            avsDeployment.avsManagerProxy,
            operationsSelectors,
            ROLE_ID_OPERATIONS_PAYMASTER
        );

        // Public selectors
        bytes4[] memory publicSelectors = new bytes4[](0);
        // publicSelectors[0] = UniFiAVSManager.TODO.selector;

        calldatas[2] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            avsDeployment.avsManagerProxy,
            publicSelectors,
            accessManager.PUBLIC_ROLE()
        );

        return calldatas;
    }
}

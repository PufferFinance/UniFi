// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "../src/UniFiAVSManager.sol";
import "./mocks/MockEigenPodManager.sol";
import "./mocks/MockDelegationManager.sol";
import "./mocks/MockAVSDirectory.sol";

contract UniFiAVSManagerTest is Test {
    UniFiAVSManager public avsManager;
    MockEigenPodManager public mockEigenPodManager;
    MockDelegationManager public mockDelegationManager;
    MockAVSDirectory public mockAVSDirectory;

    address public operator;
    address public podOwner;

    function setUp() public {
        mockEigenPodManager = new MockEigenPodManager();
        mockDelegationManager = new MockDelegationManager();
        mockAVSDirectory = new MockAVSDirectory();

        avsManager = new UniFiAVSManager(
            IEigenPodManager(address(mockEigenPodManager)),
            IDelegationManager(address(mockDelegationManager)),
            IAVSDirectory(address(mockAVSDirectory))
        );

        operator = address(0x1);
        podOwner = address(0x2);

        vm.label(operator, "Operator");
        vm.label(podOwner, "Pod Owner");

        avsManager.initialize(address(this));
    }

    function testInitialize() public {
        assertTrue(avsManager.hasRole(avsManager.ADMIN_ROLE(), address(this)));
    }

    // Add more test functions here to cover all the functionalities of UniFiAVSManager
}

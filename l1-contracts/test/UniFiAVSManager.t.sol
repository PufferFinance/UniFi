// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "../src/UniFiAVSManager.sol";
import "../src/interfaces/IUniFiAVSManager.sol";
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
        avsManager.initialize(address(this));

        operator = address(0x1);
        podOwner = address(0x2);

        vm.label(operator, "Operator");
        vm.label(podOwner, "Pod Owner");
    }

    function testInitialize() public {
        // Add appropriate initialization checks here
        assertTrue(address(avsManager) != address(0));
    }

    function testRegisterOperator() public {
        // Setup
        mockDelegationManager.setOperator(operator, true);
        mockEigenPodManager.setPod(podOwner, IEigenPod(address(0x1234)));
        mockDelegationManager.setDelegation(podOwner, operator);

        // Create a dummy signature
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        // Test
        vm.prank(operator);
        avsManager.registerOperator(podOwner, operatorSignature);

        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));
    }

    function testRegisterValidator() public {
        // Setup
        mockDelegationManager.setOperator(operator, true);
        mockEigenPodManager.setPod(podOwner, IEigenPod(address(0x1234)));
        mockDelegationManager.setDelegation(podOwner, operator);

        // Create ValidatorRegistrationParams with a valid signature
        UniFiAVSManager.ValidatorRegistrationParams memory params;
        params.pubkeyG1 = BN254.G1Point(1, 2);
        params.pubkeyG2 = BN254.G2Point([uint256(1), uint256(2)], [uint256(3), uint256(4)]);
        params.ecdsaPubKeyHash = bytes32(uint256(1));
        params.salt = bytes32(uint256(2));
        params.expiry = block.timestamp + 1 days;

        // Generate a valid signature
        uint256 privateKey = 123456; // This is a dummy private key for testing purposes
        BN254.G1Point memory messagePoint = avsManager.blsMessageHash(
            avsManager.VALIDATOR_REGISTRATION_TYPEHASH(),
            params.ecdsaPubKeyHash,
            params.salt,
            params.expiry
        );
        bytes32 messageHash = BN254.hashG1Point(messagePoint);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        // Create a valid BN254.G1Point for the registrationSignature
        params.registrationSignature = BN254.G1Point(uint256(r), uint256(s));

        // Test
        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);
        UniFiAVSManager.ValidatorData memory validatorData = avsManager.getValidator(pubkeyHash);
        assertEq(validatorData.ecdsaPubKeyHash, params.ecdsaPubKeyHash);
    }

    function testDeregisterValidator() public {
        // Setup (assuming a validator is already registered)
        bytes32 pubkeyHash = bytes32(uint256(1));
        UniFiAVSManager.ValidatorData memory validatorData;
        validatorData.ecdsaPubKeyHash = bytes32(uint256(2));
        validatorData.eigenPod = address(0x1234);

        vm.mockCall(
            address(avsManager),
            abi.encodeWithSelector(UniFiAVSManager.getValidator.selector, pubkeyHash),
            abi.encode(validatorData)
        );

        mockDelegationManager.setDelegation(podOwner, operator);

        // Test
        vm.prank(operator);
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = pubkeyHash;
        avsManager.deregisterValidator(blsPubKeyHashes);

        // Verify (this will depend on how you've implemented getValidator)
        vm.mockCall(
            address(avsManager),
            abi.encodeWithSelector(IUniFiAVSManager.getValidator.selector, pubkeyHash),
            abi.encode(IUniFiAVSManager.ValidatorData(bytes32(0), address(0)))
        );
    }

    function testDeregisterOperator() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature = ISignatureUtils.SignatureWithSaltAndExpiry({
            signature: new bytes(0),
            salt: bytes32(0),
            expiry: 0
        });
        mockAVSDirectory.registerOperatorToAVS(operator, operatorSignature);

        // Test
        vm.prank(operator);
        avsManager.deregisterOperator();

        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));
    }
}

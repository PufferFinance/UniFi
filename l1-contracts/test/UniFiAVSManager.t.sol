// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "../src/UniFiAVSManager.sol";
import "../src/interfaces/IUniFiAVSManager.sol";
import "./mocks/MockEigenPodManager.sol";
import "./mocks/MockDelegationManager.sol";
import "./mocks/MockAVSDirectory.sol";
import "eigenlayer-middleware/libraries/BN254.sol";
import "eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";

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

    function _generateBlsPubkeyParams(uint256 privKey)
        internal
        returns (IBLSApkRegistry.PubkeyRegistrationParams memory)
    {
        IBLSApkRegistry.PubkeyRegistrationParams memory pubkey;
        pubkey.pubkeyG1 = BN254.generatorG1().scalar_mul(privKey);
        pubkey.pubkeyG2 = _mulGo(privKey);
        return pubkey;
    }

    function _mulGo(uint256 privKey) internal returns (BN254.G2Point memory) {
        // This is a placeholder implementation. In a real scenario, you'd use a proper BLS library or external call.
        // For testing purposes, we're just creating a dummy G2 point.
        return BN254.G2Point([privKey, privKey], [privKey, privKey]);
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

        // Generate BLS key pair
        uint256 privateKey = 123456; // This is a dummy private key for testing purposes
        IBLSApkRegistry.PubkeyRegistrationParams memory blsKeyPair = _generateBlsPubkeyParams(privateKey);

        // Create ValidatorRegistrationParams
        UniFiAVSManager.ValidatorRegistrationParams memory params;
        params.pubkeyG1 = blsKeyPair.pubkeyG1;
        params.pubkeyG2 = blsKeyPair.pubkeyG2;
        params.ecdsaPubKeyHash = bytes32(uint256(1));
        params.salt = bytes32(uint256(2));
        params.expiry = block.timestamp + 1 days;

        // Generate a valid signature
        BN254.G1Point memory messagePoint = avsManager.blsMessageHash(
            avsManager.VALIDATOR_REGISTRATION_TYPEHASH(),
            params.ecdsaPubKeyHash,
            params.salt,
            params.expiry
        );
        params.registrationSignature = messagePoint.scalar_mul(privateKey);

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

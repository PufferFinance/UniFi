// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "../src/UniFiAVSManager.sol";
import "../src/interfaces/IUniFiAVSManager.sol";
import "../src/structs/ValidatorRegistrationParams.sol";
import "../src/structs/ValidatorData.sol";
import "../src/structs/OperatorData.sol";
import "./mocks/MockEigenPodManager.sol";
import "./mocks/MockDelegationManager.sol";
import "./mocks/MockAVSDirectory.sol";
import "eigenlayer-middleware/libraries/BN254.sol";
import "eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {UnitTestHelper} from "../test/helpers/UnitTestHelper.sol";

contract UniFiAVSManagerTest is UnitTestHelper {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    // TEST HELPERS

    function _generateBlsPubkeyParams(
        uint256 privKey
    ) internal returns (IBLSApkRegistry.PubkeyRegistrationParams memory) {
        IBLSApkRegistry.PubkeyRegistrationParams memory pubkey;
        pubkey.pubkeyG1 = BN254.generatorG1().scalar_mul(privKey);
        pubkey.pubkeyG2 = _mulGo(privKey);
        return pubkey;
    }

    function _mulGo(uint256 x) internal returns (BN254.G2Point memory g2Point) {
        string[] memory inputs = new string[](3);
        inputs[0] = "./test/helpers/go2mul-mac"; // lib/eigenlayer-middleware/test/ffi/go/g2mul.go binary
        // inputs[0] = "./test/helpers/go2mul"; // lib/eigenlayer-middleware/test/ffi/go/g2mul.go binary
        inputs[1] = x.toString();

        inputs[2] = "1";
        bytes memory res = vm.ffi(inputs);
        g2Point.X[1] = abi.decode(res, (uint256));

        inputs[2] = "2";
        res = vm.ffi(inputs);
        g2Point.X[0] = abi.decode(res, (uint256));

        inputs[2] = "3";
        res = vm.ffi(inputs);
        g2Point.Y[1] = abi.decode(res, (uint256));

        inputs[2] = "4";
        res = vm.ffi(inputs);
        g2Point.Y[0] = abi.decode(res, (uint256));
    }

    // With ECDSA key, he sign the hash confirming that the operator wants to be registered to a certain restaking service
    function _getOperatorSignature(
        uint256 _operatorPrivateKey,
        address _operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    )
        internal
        view
        returns (
            bytes32 digestHash,
            ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
        )
    {
        operatorSignature.expiry = expiry;
        operatorSignature.salt = salt;
        {
            digestHash = mockAVSDirectory
                .calculateOperatorAVSRegistrationDigestHash(
                    operator,
                    avs,
                    salt,
                    expiry
                );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                _operatorPrivateKey,
                digestHash
            );
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        return (digestHash, operatorSignature);
    }

    function _setupOperator() internal {
        mockDelegationManager.setOperator(operator, true);
        mockEigenPodManager.createPod(podOwner);
        mockDelegationManager.setDelegation(podOwner, operator);
    }

    function _registerOperatorParams(
        bytes32 salt,
        uint256 expiry
    ) internal returns (ISignatureUtils.SignatureWithSaltAndExpiry memory) {
        (
            bytes32 digestHash,
            ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
        ) = _getOperatorSignature(
                operatorPrivateKey,
                operator,
                address(avsManager),
                salt,
                expiry
            );

        return operatorSignature;
    }

    function _setupValidator(
        uint256 privateKey,
        bytes memory delegatePubKey
    ) internal returns (ValidatorRegistrationParams memory, bytes32) {
        IBLSApkRegistry.PubkeyRegistrationParams
            memory blsKeyPair = _generateBlsPubkeyParams(privateKey);

        ValidatorRegistrationParams memory params;
        params.pubkeyG1 = blsKeyPair.pubkeyG1;
        params.pubkeyG2 = blsKeyPair.pubkeyG2;
        params.delegatePubKey = delegatePubKey;
        params.salt = bytes32(uint256(2));
        params.expiry = block.timestamp + 1 days;

        BN254.G1Point memory messagePoint = avsManager.blsMessageHash(
            avsManager.VALIDATOR_REGISTRATION_TYPEHASH(),
            params.delegatePubKey,
            params.salt,
            params.expiry
        );
        params.registrationSignature = messagePoint.scalar_mul(privateKey);

        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);
        mockEigenPodManager.createPod(podOwner);
        mockEigenPodManager.setValidatorStatus(
            podOwner,
            pubkeyHash,
            IEigenPod.VALIDATOR_STATUS.ACTIVE
        );

        return (params, pubkeyHash);
    }

    function _registerValidator(
        uint256 privateKey,
        bytes memory delegatePubKey,
        bool setupOperator,
        bool registerOperator,
        bool setupValidator,
        bool modifyParams
    ) internal returns (bytes32, ValidatorRegistrationParams memory) {
        if (setupOperator) {
            _setupOperator();
        }

        if (registerOperator) {
            ISignatureUtils.SignatureWithSaltAndExpiry
                memory operatorSignature = _registerOperatorParams({
                    salt: bytes32(uint256(1)),
                    expiry: uint256(block.timestamp + 1 days)
                });

            vm.prank(operator);
            avsManager.registerOperator(operatorSignature);
        }

        ValidatorRegistrationParams memory params;
        bytes32 pubkeyHash;

        if (setupValidator) {
            (params, pubkeyHash) = _setupValidator(privateKey, delegatePubKey);
        }

        if (modifyParams) {
            // Modify params for unhappy path tests
            params.expiry = block.timestamp - 1; // Set expired timestamp
        }

        return (pubkeyHash, params);
    }

    // BEGIN TESTS

    function testInitialize() public {
        // todo add appropriate initialization checks here
        assertTrue(address(avsManager) != address(0));
    }

    function testRegisterOperator() public {
        _setupOperator();
        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));

        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams({
                salt: bytes32(uint256(1)),
                expiry: uint256(block.timestamp + 1 days)
            });

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));
    }

    function testRegisterOperator_AlreadyRegistered() public {
        _setupOperator();

        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams({
                salt: bytes32(uint256(1)),
                expiry: uint256(block.timestamp + 1 days)
            });

        // 1st registration
        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);
        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));

        // 2nd registration
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorAlreadyRegistered.selector);
        avsManager.registerOperator(operatorSignature);
    }

    function testRegisterOperator_ExpiredSignature() public {
        _setupOperator();

        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams({
                salt: bytes32(uint256(1)),
                expiry: uint256(block.timestamp - 1) // expired timestamp
            });

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.SignatureExpired.selector);
        avsManager.registerOperator(operatorSignature);
    }

    function testRegisterOperator_ReusedSalt() public {
        _setupOperator();

        bytes32 salt = bytes32(uint256(1));
        uint256 expiry = block.timestamp + 1 days;

        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams(salt, expiry);

        // First registration should succeed
        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        // Create a new operator
        address newOperator = address(0x456);
        uint256 newOperatorPrivateKey = 789;
        vm.prank(newOperator);
        mockDelegationManager.setOperator(newOperator, true);

        // Try to register the new operator with the same salt
        (
            ,
            ISignatureUtils.SignatureWithSaltAndExpiry
                memory newOperatorSignature
        ) = _getOperatorSignature(
                newOperatorPrivateKey,
                newOperator,
                address(avsManager),
                salt,
                expiry
            );

        vm.prank(newOperator);
        vm.expectRevert(IUniFiAVSManager.InvalidOperatorSalt.selector);
        avsManager.registerOperator(newOperatorSignature);
    }

    function testRegisterValidator() public {
        uint256 privateKey = 123456; // This is a dummy private key for testing purposes
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 blsPubKeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        // Verify they registered
        (ValidatorData memory validatorData, bool _backedByStake) = avsManager.getValidator(
            blsPubKeyHash
        );
        assertEq(validatorData.delegatePubKey, delegatePubKey);

        OperatorData memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 1);
    }

    function testRegisterValidator_OperatorNotRegistered() public {
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (, ValidatorRegistrationParams memory params) = _registerValidator(
            privateKey,
            delegatePubKey,
            true, // setupOperator
            false, // don't register operator
            true, // setupValidator
            false // don't modify params
        );

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.registerValidator(podOwner, params);
    }

    function testRegisterValidator_RegistrationExpired() public {
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (, ValidatorRegistrationParams memory params) = _registerValidator(
            privateKey,
            delegatePubKey,
            true, // setupOperator
            true, // registerOperator
            true, // setupValidator
            true // modify params (set expired timestamp)
        );

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.RegistrationExpired.selector);
        avsManager.registerValidator(podOwner, params);
    }

    function testRegisterValidator_InvalidRegistrationSalt() public {
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 _hash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        // Register the validator once
        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        // Try to register again with the same salt
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.InvalidRegistrationSalt.selector);
        avsManager.registerValidator(podOwner, params);
    }

    function testRegisterValidator_ValidatorNotActive() public {
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 pubkeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        // Set validator status to inactive
        mockEigenPodManager.setValidatorStatus(
            podOwner,
            pubkeyHash,
            IEigenPod.VALIDATOR_STATUS.INACTIVE
        );

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.ValidatorNotActive.selector);
        avsManager.registerValidator(podOwner, params);
    }

    function testDeregisterValidator() public {
        bytes32[] memory pubkeyHashes = new bytes32[](1);

        uint256 privateKey = 123456; // This is a dummy private key for testing purposes
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 blsPubKeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);
        pubkeyHashes[0] = blsPubKeyHash;

        OperatorData memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 1);

        vm.startPrank(operator);
        avsManager.deregisterValidator(pubkeyHashes);

        operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 0);
    }

    function testDeregisterValidator_NotDelegatedToOperator() public {
        bytes32[] memory pubkeyHashes = new bytes32[](1);

        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 blsPubKeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);
        pubkeyHashes[0] = blsPubKeyHash;

        // Change delegation to a different operator
        address newOperator = address(0x789);
        mockDelegationManager.setDelegation(podOwner, newOperator);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.NotDelegatedToOperator.selector);
        avsManager.deregisterValidator(pubkeyHashes);

        OperatorData memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 1);
    }

    function testDeregisterValidator_NonExistentValidator() public {
        bytes32[] memory pubkeyHashes = new bytes32[](1);
        pubkeyHashes[0] = bytes32(uint256(1)); // Non-existent validator

        vm.prank(operator);
        vm.expectRevert(); // Expect a revert, but the exact error message depends EigenPod
        avsManager.deregisterValidator(pubkeyHashes);
    }

    function testDeregisterValidator_UnauthorizedCaller() public {
        bytes32[] memory pubkeyHashes = new bytes32[](1);

        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 blsPubKeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true,
                true,
                true,
                false
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);
        pubkeyHashes[0] = blsPubKeyHash;

        address unauthorizedCaller = address(0x123);
        vm.prank(unauthorizedCaller);
        vm.expectRevert(IUniFiAVSManager.NotDelegatedToOperator.selector);
        avsManager.deregisterValidator(pubkeyHashes);

        OperatorData memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 1);
    }

    function testDeregisterOperator() public {
        _setupOperator();
        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams({
                salt: bytes32(uint256(1)),
                expiry: uint256(block.timestamp + 1 days)
            });

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        vm.prank(operator);
        avsManager.deregisterOperator();

        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));
    }

    function testDeregisterOperator_NotRegistered() public {
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.deregisterOperator();
    }

    function testDeregisterOperator_HasValidators() public {
        // Register a validator
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            ,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator 
                true, // registerOperator 
                true, // setupValidator
                false // don't modify params
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorHasValidators.selector);
        avsManager.deregisterOperator();
    }

    function testDeregisterOperator_UnauthorizedCaller() public {
        _setupOperator();
        ISignatureUtils.SignatureWithSaltAndExpiry
            memory operatorSignature = _registerOperatorParams({
                salt: bytes32(uint256(1)),
                expiry: uint256(block.timestamp + 1 days)
            });

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        address unauthorizedCaller = address(0x123);
        vm.prank(unauthorizedCaller);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.deregisterOperator();

        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));
    }

    function testGetValidator_BackedByStakeFalse() public {
        uint256 privateKey = 123456;
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        (
            bytes32 blsPubKeyHash,
            ValidatorRegistrationParams memory params
        ) = _registerValidator(
                privateKey,
                delegatePubKey,
                true, // setupOperator
                true, // registerOperator
                true, // setupValidator
                false // don't modify params
            );

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        // Change delegation to a different address
        address randomAddress = makeAddr("random");
        mockDelegationManager.setDelegation(podOwner, randomAddress);

        (ValidatorData memory validatorData, bool backedByStake) = avsManager.getValidator(blsPubKeyHash);

        assertEq(validatorData.delegatePubKey, delegatePubKey);
        assertFalse(backedByStake, "backedByStake should be false when delegated to a different address");
    }
}

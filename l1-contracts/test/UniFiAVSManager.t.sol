// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "../src/UniFiAVSManager.sol";
import "../src/interfaces/IUniFiAVSManager.sol";
import "../src/structs/ValidatorData.sol";
import "../src/structs/OperatorData.sol";
import "./mocks/MockEigenPodManager.sol";
import "./mocks/MockDelegationManager.sol";
import "./mocks/MockAVSDirectory.sol";
import "eigenlayer-middleware/libraries/BN254.sol";
import "eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitTestHelper } from "../test/helpers/UnitTestHelper.sol";

contract UniFiAVSManagerTest is UnitTestHelper {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    bytes delegatePubKey = abi.encodePacked(uint256(1337));

    // TEST HELPERS

    function _generateBlsPubkeyParams(uint256 privKey)
        internal
        returns (IBLSApkRegistry.PubkeyRegistrationParams memory)
    {
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
    ) internal view returns (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        operatorSignature.expiry = expiry;
        operatorSignature.salt = salt;
        {
            digestHash = mockAVSDirectory.calculateOperatorAVSRegistrationDigestHash(operator, avs, salt, expiry);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_operatorPrivateKey, digestHash);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        return (digestHash, operatorSignature);
    }

    function _setupOperator() internal {
        mockDelegationManager.setOperator(operator, true);
        mockEigenPodManager.createPod(podOwner);
        mockDelegationManager.setDelegation(podOwner, operator);
    }

    function _registerOperatorParams(bytes32 salt, uint256 expiry)
        internal
        returns (ISignatureUtils.SignatureWithSaltAndExpiry memory)
    {
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
            _getOperatorSignature(operatorPrivateKey, operator, address(avsManager), salt, expiry);

        return operatorSignature;
    }

    function _registerOperator() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            _registerOperatorParams({ salt: bytes32(uint256(1)), expiry: uint256(block.timestamp + 1 days) });

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        _setOperatorDelegateKey(operator, delegatePubKey);
    }

    function _setOperatorDelegateKey(address _operator, bytes memory _delegateKey) internal {
        vm.prank(_operator);
        avsManager.setOperatorDelegateKey(_delegateKey);

        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.prank(_operator);
        avsManager.updateOperatorDelegateKey();
    }

    // BEGIN TESTS

    function testInitialize() public {
        // todo add appropriate initialization checks here
        assertTrue(address(avsManager) != address(0));
    }

    function test_registerOperatorHelper() public {
        _setupOperator();
        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));
        _registerOperator();
        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.delegateKey, delegatePubKey);
    }

    function testRegisterOperator() public {
        _setupOperator();
        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            _registerOperatorParams({ salt: bytes32(uint256(1)), expiry: uint256(block.timestamp + 1 days) });

        vm.expectEmit(true, false, false, false);
        emit IUniFiAVSManager.OperatorRegistered(operator);

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);

        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 0);
        assertEq(operatorData.delegateKey, "");
        assertEq(operatorData.startOperatorDeregisterBlock, 0);
        assertTrue(operatorData.isRegistered);
    }

    function testRegisterOperator_AlreadyRegistered() public {
        _setupOperator();

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            _registerOperatorParams({ salt: bytes32(uint256(1)), expiry: uint256(block.timestamp + 1 days) });

        // 1st registration
        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);
        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));

        // 2nd registration
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorAlreadyRegistered.selector);
        avsManager.registerOperator(operatorSignature);
    }

    function _setupValidators(bytes32[] memory blsPubKeyHashes) internal {
        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            mockEigenPodManager.setValidatorStatus(podOwner, blsPubKeyHashes[i], IEigenPod.VALIDATOR_STATUS.ACTIVE);
        }
    }

    function testRegisterValidators() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](2);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));
        blsPubKeyHashes[1] = keccak256(abi.encodePacked("validator2"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 2);
        assertEq(operatorData.delegateKey, delegatePubKey);

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertEq(validatorData.eigenPod, address(mockEigenPodManager.getPod(podOwner)));
            assertEq(validatorData.operator, operator);
            assertTrue(validatorData.backedByStake);
        }
    }

    function testRegisterValidators_OperatorNotRegistered() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);
    }

    function testRegisterValidators_DelegateKeyNotSet() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        // Clear the delegate key
        _setOperatorDelegateKey(operator, "");

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.DelegateKeyNotSet.selector);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);
    }

    function testRegisterValidators_ValidatorNotActive() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();

        // Set validator status to inactive
        mockEigenPodManager.setValidatorStatus(podOwner, blsPubKeyHashes[0], IEigenPod.VALIDATOR_STATUS.INACTIVE);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.ValidatorNotActive.selector);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);
    }

    function testRegisterValidators_ValidatorAlreadyRegistered() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        // Register the validator once
        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        // Try to register again
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.ValidatorAlreadyRegistered.selector);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);
    }

    function testDeregisterValidators() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](2);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));
        blsPubKeyHashes[1] = keccak256(abi.encodePacked("validator2"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 2);

        uint256 initialBlockNumber = block.number;
        vm.prank(operator);
        avsManager.deregisterValidators(blsPubKeyHashes);

        operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 0, "all validators should be deregistered");

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertEq(
                validatorData.registeredUntil,
                initialBlockNumber + avsManager.getDeregistrationDelay(),
                "registeredUntil should be the deregistrationDelay"
            );
            assertTrue(validatorData.registered, "Validator should be registered");
        }

        // Advance block number to just before the deregistration delay
        vm.roll(initialBlockNumber + avsManager.getDeregistrationDelay() - 1);

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertTrue(validatorData.registered, "Validator should be registered before deregistrationDelay blocks");
        }

        // Advance block number to the deregistration delay
        vm.roll(initialBlockNumber + avsManager.getDeregistrationDelay());

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertFalse(validatorData.registered, "Validator should not be registered at deregistrationDelay blocks");
        }

        // Advance block number past the deregistration delay
        vm.roll(initialBlockNumber + avsManager.getDeregistrationDelay() + 1);

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertFalse(validatorData.registered, "Validator should not be registered after deregistrationDelay blocks");
        }
    }

    function testDeregisterValidators_ValidatorNotFound() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.ValidatorNotFound.selector);
        avsManager.deregisterValidators(blsPubKeyHashes);
    }

    function testDeregisterValidators_NotValidatorOperator() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        // Setup and register the first operator
        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        // Setup and register the second operator
        address secondOperator = address(0x456);
        uint256 secondOperatorPrivateKey = 789;
        vm.prank(secondOperator);
        mockDelegationManager.setOperator(secondOperator, true);

        ISignatureUtils.SignatureWithSaltAndExpiry memory secondOperatorSignature =
            _registerOperatorParams({ salt: bytes32(uint256(2)), expiry: uint256(block.timestamp + 1 days) });

        vm.prank(secondOperator);
        avsManager.registerOperator(secondOperatorSignature);

        // Attempt to deregister validators with the second operator
        vm.prank(secondOperator);
        vm.expectRevert(IUniFiAVSManager.NotValidatorOperator.selector);
        avsManager.deregisterValidators(blsPubKeyHashes);

        // Verify that the validators are still registered to the first operator
        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 1);
    }

    function testDeregisterValidators_NotActiveValidator() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        // Setup and register the first operator
        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);
        mockEigenPodManager.setValidatorStatus(podOwner, blsPubKeyHashes[0], IEigenPod.VALIDATOR_STATUS.WITHDRAWN);

        // Setup and register a random address
        address randomAddress = address(0x456);

        vm.prank(randomAddress);
        avsManager.deregisterValidators(blsPubKeyHashes);

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 0);

        for (uint256 i = 0; i < blsPubKeyHashes.length; i++) {
            ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[i]);
            assertEq(validatorData.registeredUntil, block.number + avsManager.getDeregistrationDelay());
            assertTrue(validatorData.registered);
        }
    }

    function testStartDeregisterOperator() public {
        _setupOperator();
        _registerOperator();

        vm.expectEmit(true, false, false, false);
        emit IUniFiAVSManager.OperatorDeregisterStarted(operator);

        vm.prank(operator);
        avsManager.startDeregisterOperator();

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.startOperatorDeregisterBlock, block.number);
    }

    function testStartDeregisterOperator_NotRegistered() public {
        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.startDeregisterOperator();
    }

    function testStartDeregisterOperator_HasValidators() public {
        _setupOperator();
        _registerOperator();

        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorHasValidators.selector);
        avsManager.startDeregisterOperator();
    }

    function testStartDeregisterOperator_AlreadyStarted() public {
        _setupOperator();
        _registerOperator();
        vm.roll(1); // advance so not at block 0

        vm.prank(operator);
        avsManager.startDeregisterOperator();

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.DeregistrationAlreadyStarted.selector);
        avsManager.startDeregisterOperator();
    }

    function testFinishDeregisterOperator() public {
        _setupOperator();
        _registerOperator();
        vm.roll(1); // advance so not at block 0

        vm.prank(operator);
        avsManager.startDeregisterOperator();

        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.expectEmit(true, false, false, false);
        emit IUniFiAVSManager.OperatorDeregistered(operator);

        vm.prank(operator);
        avsManager.finishDeregisterOperator();

        assertFalse(mockAVSDirectory.isOperatorRegistered(operator), "Operator should be deregistered");
    }

    function testFinishDeregisterOperator_NotStarted() public {
        _setupOperator();
        _registerOperator();
        vm.roll(1); // advance so not at block 0

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.DeregistrationNotStarted.selector);
        avsManager.finishDeregisterOperator();
    }

    function testFinishDeregisterOperator_DelayNotElapsed() public {
        _setupOperator();
        _registerOperator();
        vm.roll(1); // advance so not at block 0

        vm.prank(operator);
        avsManager.startDeregisterOperator();

        vm.roll(block.number + avsManager.getDeregistrationDelay() - 1);

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.DeregistrationDelayNotElapsed.selector);
        avsManager.finishDeregisterOperator();
    }

    function testFinishDeregisterOperator_NotRegistered() public {
        vm.prank(operator);
        vm.roll(1); // advance so not at block 0
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.finishDeregisterOperator();
    }

    // Test removed as lastDeregisterBlock functionality no longer exists

    // Test removed as lastDeregisterBlock functionality no longer exists

    function testSetDeregistrationDelay() public {
        uint64 newDelay = 100;
        uint64 oldDelay = avsManager.getDeregistrationDelay();

        vm.expectEmit(true, true, false, true);
        emit IUniFiAVSManager.DeregistrationDelaySet(oldDelay, newDelay);

        vm.prank(DAO);
        avsManager.setDeregistrationDelay(newDelay);

        assertEq(avsManager.getDeregistrationDelay(), newDelay, "Deregistration delay should be updated");
    }

    // function testSetDeregistrationDelay_Unauthorized() public {
    //     uint64 newDelay = 100;
    //     address unauthorizedUser = makeAddr("unauthorizedUser");

    //     vm.prank(unauthorizedUser);
    //     vm.expectRevert("AccessManaged: sender is not authorized");
    //     avsManager.setDeregistrationDelay(newDelay);

    //     assertEq(avsManager.getDeregistrationDelay(), DEREGISTRATION_DELAY, "Deregistration delay should not change");
    // }

    // Test removed as lastDeregisterBlock functionality no longer exists

    function testGetValidator_BackedByStakeFalse() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        // Change delegation to a different address
        address randomAddress = makeAddr("random");
        mockDelegationManager.setDelegation(podOwner, randomAddress);

        ValidatorDataExtended memory validatorData = avsManager.getValidator(blsPubKeyHashes[0]);

        assertEq(validatorData.operator, operator);
        assertFalse(validatorData.backedByStake, "backedByStake should be false when delegated to a different address");
    }

    function testSetOperatorDelegateKey() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));

        vm.prank(operator);
        avsManager.setOperatorDelegateKey(newDelegateKey);

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.delegateKey, delegatePubKey, "Delegate key should not change immediately");
        assertEq(operatorData.pendingDelegateKey, newDelegateKey, "Pending delegate key should be set");
        assertEq(
            operatorData.delegateKeyValidAfter,
            block.number + avsManager.getDeregistrationDelay(),
            "Delegate key valid after should be set correctly"
        );
    }

    function testUpdateOperatorDelegateKey() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));

        vm.prank(operator);
        avsManager.setOperatorDelegateKey(newDelegateKey);

        // advance to the update block
        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.expectEmit(true, false, false, true);
        emit IUniFiAVSManager.OperatorDelegateKeySet(operator, delegatePubKey, newDelegateKey);

        vm.prank(operator);
        avsManager.updateOperatorDelegateKey();

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.delegateKey, newDelegateKey, "Delegate key should be updated");
        assertEq(operatorData.pendingDelegateKey, "", "Pending delegate key should be cleared");
        assertEq(operatorData.delegateKeyValidAfter, 0, "Delegate key valid after should be reset");
    }

    function testUpdateOperatorDelegateKey_TooEarly() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));

        vm.prank(operator);
        avsManager.setOperatorDelegateKey(newDelegateKey);

        vm.roll(block.number + avsManager.getDeregistrationDelay() - 1);

        vm.expectRevert(DelegateKeyChangeNotReady.selector);
        vm.prank(operator);
        avsManager.updateOperatorDelegateKey();
    }

    function testSetOperatorDelegateKey_NotRegistered() public {
        bytes memory newDelegateKey = abi.encodePacked(uint256(2));

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.setOperatorDelegateKey(newDelegateKey);
    }
}

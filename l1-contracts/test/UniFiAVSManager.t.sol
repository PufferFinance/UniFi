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

        _setOperatorCommitment(operator, delegatePubKey, 0);
    }

    function _setOperatorCommitment(address _operator, bytes memory _delegateKey, uint256 _chainIDBitMap) internal {
        vm.prank(_operator);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: _delegateKey, chainIDBitMap: _chainIDBitMap })
        );

        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.prank(_operator);
        avsManager.updateOperatorCommitment();
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
        assertEq(operatorData.commitment.delegateKey, delegatePubKey);
        assertEq(operatorData.commitment.chainIDBitMap, 0);
        assertEq(operatorData.pendingCommitment.delegateKey, "");
        assertEq(operatorData.pendingCommitment.chainIDBitMap, 0);
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
        assertEq(operatorData.commitment.delegateKey, "");
        assertEq(operatorData.commitment.chainIDBitMap, 0);
        assertEq(operatorData.pendingCommitment.delegateKey, "");
        assertEq(operatorData.pendingCommitment.chainIDBitMap, 0);
        assertEq(operatorData.startDeregisterOperatorBlock, 0);
        assertEq(operatorData.commitmentValidAfter, 0);
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
        assertEq(operatorData.commitment.delegateKey, delegatePubKey);

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
        _setOperatorCommitment(operator, "", 0);

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
        assertEq(operatorData.startDeregisterOperatorBlock, uint128(block.number));
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

    function testSetDeregistrationDelay() public {
        uint64 newDelay = 100;
        uint64 oldDelay = avsManager.getDeregistrationDelay();

        vm.expectEmit(true, true, false, true);
        emit IUniFiAVSManager.DeregistrationDelaySet(oldDelay, newDelay);

        vm.prank(DAO);
        avsManager.setDeregistrationDelay(newDelay);

        assertEq(avsManager.getDeregistrationDelay(), newDelay, "Deregistration delay should be updated");
    }

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

    function testSetOperatorCommitment() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));
        uint256 newChainIDBitMap = 3; // 0b11

        vm.prank(operator);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: newDelegateKey, chainIDBitMap: newChainIDBitMap })
        );

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.commitment.delegateKey, delegatePubKey, "Delegate key should not change immediately");
        assertEq(operatorData.commitment.chainIDBitMap, 0, "Chain ID bitmap should not change immediately");
        assertEq(operatorData.pendingCommitment.delegateKey, newDelegateKey, "Pending delegate key should be set");
        assertEq(
            operatorData.pendingCommitment.chainIDBitMap, newChainIDBitMap, "Pending chain ID bitmap should be set"
        );
        assertEq(
            operatorData.commitmentValidAfter,
            block.number + avsManager.getDeregistrationDelay(),
            "Commitment valid after should be set correctly"
        );
    }

    function testUpdateOperatorCommitment() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));
        uint256 newChainIDBitMap = 3; // 0b11

        vm.prank(operator);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: newDelegateKey, chainIDBitMap: newChainIDBitMap })
        );

        // advance to the update block
        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.expectEmit(true, false, false, true);
        emit IUniFiAVSManager.OperatorCommitmentSet(
            operator,
            OperatorCommitment({ delegateKey: delegatePubKey, chainIDBitMap: 0 }),
            OperatorCommitment({ delegateKey: newDelegateKey, chainIDBitMap: newChainIDBitMap })
        );

        vm.prank(operator);
        avsManager.updateOperatorCommitment();

        OperatorDataExtended memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.commitment.delegateKey, newDelegateKey, "Delegate key should be updated");
        assertEq(operatorData.commitment.chainIDBitMap, newChainIDBitMap, "Chain ID bitmap should be updated");
        assertEq(operatorData.pendingCommitment.delegateKey, "", "Pending delegate key should be cleared");
        assertEq(operatorData.pendingCommitment.chainIDBitMap, 0, "Pending chain ID bitmap should be cleared");
        assertEq(operatorData.commitmentValidAfter, 0, "Commitment valid after should be reset");
    }

    function testUpdateOperatorCommitment_TooEarly() public {
        _setupOperator();
        _registerOperator();

        bytes memory newDelegateKey = abi.encodePacked(uint256(2));
        uint256 newChainIDBitMap = 3; // 0b11

        vm.prank(operator);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: newDelegateKey, chainIDBitMap: newChainIDBitMap })
        );

        vm.roll(block.number + avsManager.getDeregistrationDelay() - 1);

        vm.expectRevert(IUniFiAVSManager.CommitmentChangeNotReady.selector);
        vm.prank(operator);
        avsManager.updateOperatorCommitment();
    }

    function testSetOperatorCommitment_NotRegistered() public {
        bytes memory newDelegateKey = abi.encodePacked(uint256(2));
        uint256 newChainIDBitMap = 3; // 0b11

        vm.prank(operator);
        vm.expectRevert(IUniFiAVSManager.OperatorNotRegistered.selector);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: newDelegateKey, chainIDBitMap: newChainIDBitMap })
        );
    }

    function testSetAndGetChainID() public {
        vm.startPrank(DAO);

        uint32 chainID1 = 1; // Ethereum Mainnet
        uint32 chainID2 = 10; // Optimism

        avsManager.setChainID(1, chainID1);
        avsManager.setChainID(2, chainID2);

        assertEq(avsManager.getChainID(1), chainID1, "ChainID at index 1 should match");
        assertEq(avsManager.getChainID(2), chainID2, "ChainID at index 2 should match");

        vm.stopPrank();
    }

    function testSetChainIDOutOfBounds() public {
        vm.startPrank(DAO);

        vm.expectRevert(IndexOutOfBounds.selector);
        avsManager.setChainID(0, 1);

        vm.expectRevert(IndexOutOfBounds.selector);
        avsManager.setChainID(256, 1);

        vm.stopPrank();
    }

    function testSetChainIDUnauthorized() public {
        address unauthorizedUser = address(0x1234);
        vm.prank(unauthorizedUser);
        vm.expectRevert(); // todo get correct Unauthorized.selector
        avsManager.setChainID(0, 1);
    }

    function testGetChainIDOutOfBounds() public {
        vm.expectRevert(IndexOutOfBounds.selector);
        avsManager.getChainID(0);

        vm.expectRevert(IndexOutOfBounds.selector);
        avsManager.getChainID(256);
    }

    function testSetDeregistrationDelayUnauthorized() public {
        address unauthorizedUser = address(0x1234);
        vm.prank(unauthorizedUser);
        vm.expectRevert(); // todo get correct Unauthorized.selector
        avsManager.setDeregistrationDelay(100);
    }

    function testBitmapToChainIDs() public {
        vm.startPrank(DAO);

        avsManager.setChainID(1, 1); // Ethereum Mainnet
        avsManager.setChainID(2, 10); // Optimism
        avsManager.setChainID(3, 137); // Polygon

        uint256 bitmap = 0xE; // 0b1110

        uint32[] memory chainIDs = avsManager.bitmapToChainIDs(bitmap);

        assertEq(chainIDs.length, 3, "Should return 3 chainIDs");
        assertEq(chainIDs[0], 1, "First chainID should match");
        assertEq(chainIDs[1], 10, "Second chainID should match");
        assertEq(chainIDs[2], 137, "Third chainID should match");

        vm.stopPrank();
    }

    function testBitmapToChainIDsWithGaps() public {
        vm.startPrank(DAO);

        avsManager.setChainID(1, 1); // Ethereum Mainnet
        avsManager.setChainID(3, 137); // Polygon

        uint256 bitmap = 0xA; // 0b1010

        uint32[] memory chainIDs = avsManager.bitmapToChainIDs(bitmap);

        assertEq(chainIDs.length, 2, "Should return 2 chainIDs");
        assertEq(chainIDs[0], 1, "First chainID should match");
        assertEq(chainIDs[1], 137, "Second chainID should match");

        vm.stopPrank();
    }

    function testGetBitmapIndex() public {
        vm.startPrank(DAO);

        uint32 chainID1 = 1; // Ethereum Mainnet
        uint32 chainID2 = 10; // Optimism

        avsManager.setChainID(1, chainID1);
        avsManager.setChainID(2, chainID2);

        assertEq(avsManager.getBitmapIndex(chainID1), 1, "Bitmap index for chainID1 should be 1");
        assertEq(avsManager.getBitmapIndex(chainID2), 2, "Bitmap index for chainID2 should be 2");

        vm.stopPrank();
    }

    function testGetBitmapIndexNonExistent() public {
        uint32 nonExistentChainID = 999;

        assertEq(
            avsManager.getBitmapIndex(nonExistentChainID),
            type(uint8).max,
            "Bitmap index for non-existent chainID should be type(uint8).max"
        );
    }

    function testIsValidatorInChainId() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        // Set chain IDs
        vm.startPrank(DAO);
        avsManager.setChainID(1, 1); // Ethereum Mainnet
        avsManager.setChainID(2, 10); // Optimism
        avsManager.setChainID(3, 137); // Polygon
        vm.stopPrank();

        // Set a chainIDBitMap for the operator
        uint256 chainIDBitMap = 0x5; // 0b101, active for chain IDs at index 1 and 3
        _setOperatorCommitment(operator, delegatePubKey, chainIDBitMap);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        assertTrue(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 1), "Validator should be in Ethereum Mainnet");
        assertFalse(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 10), "Validator should not be in Optimism");
        assertTrue(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 137), "Validator should be in Polygon");
        assertFalse(
            avsManager.isValidatorInChainId(blsPubKeyHashes[0], 42161), "Validator should not be in Arbitrum One"
        );
    }

    function testIsValidatorInChainId_ValidatorNotFound() public {
        bytes32 nonExistentValidator = keccak256(abi.encodePacked("nonExistentValidator"));

        assertFalse(
            avsManager.isValidatorInChainId(nonExistentValidator, 1),
            "Non-existent validator should not be in any chain"
        );
    }

    function testIsValidatorInChainId_AfterCommitmentChange() public {
        bytes32[] memory blsPubKeyHashes = new bytes32[](1);
        blsPubKeyHashes[0] = keccak256(abi.encodePacked("validator1"));

        _setupOperator();
        _registerOperator();
        _setupValidators(blsPubKeyHashes);

        // Set chain IDs
        vm.startPrank(DAO);
        avsManager.setChainID(1, 1); // Ethereum Mainnet
        avsManager.setChainID(2, 10); // Optimism
        avsManager.setChainID(3, 137); // Polygon
        vm.stopPrank();

        // Initial chainIDBitMap
        uint256 initialChainIDBitMap = 0x5; // 0b101, active for chain IDs at index 1 and 3
        _setOperatorCommitment(operator, delegatePubKey, initialChainIDBitMap);

        vm.prank(operator);
        avsManager.registerValidators(podOwner, blsPubKeyHashes);

        // Change the commitment
        uint256 newChainIDBitMap = 0x6; // 0b110, active for chain IDs at index 2 and 3
        vm.prank(operator);
        avsManager.setOperatorCommitment(
            OperatorCommitment({ delegateKey: delegatePubKey, chainIDBitMap: newChainIDBitMap })
        );

        // Before the commitment change takes effect
        assertTrue(
            avsManager.isValidatorInChainId(blsPubKeyHashes[0], 1), "Validator should still be in Ethereum Mainnet"
        );
        assertFalse(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 10), "Validator should not yet be in Optimism");

        // Advance to make the new commitment active
        vm.roll(block.number + avsManager.getDeregistrationDelay());

        vm.prank(operator);
        avsManager.updateOperatorCommitment();

        // After the commitment change takes effect
        assertFalse(
            avsManager.isValidatorInChainId(blsPubKeyHashes[0], 1), "Validator should no longer be in Ethereum Mainnet"
        );
        assertTrue(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 10), "Validator should now be in Optimism");
        assertTrue(avsManager.isValidatorInChainId(blsPubKeyHashes[0], 137), "Validator should still be in Polygon");
    }
}

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
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitTestHelper } from "../test/helpers/UnitTestHelper.sol";

contract UniFiAVSManagerTest is UnitTestHelper {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

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

    function _registerOperator() internal {
        bytes32 salt = bytes32(uint256(1));
        uint256 expiry = block.timestamp + 1 days;
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
            _getOperatorSignature(operatorPrivateKey, operator, address(avsManager), salt, expiry);

        vm.prank(operator);
        avsManager.registerOperator(operatorSignature);
    }

    function _registerValidator(uint256 privateKey, bytes memory delegatePubKey) internal returns (bytes32) {
        (ValidatorRegistrationParams memory params, bytes32 pubkeyHash) = _setupValidator(privateKey, delegatePubKey);

        vm.prank(operator);
        avsManager.registerValidator(podOwner, params);

        return pubkeyHash;
    }

    function _setupValidator(uint256 privateKey, bytes memory delegatePubKey) internal returns (ValidatorRegistrationParams memory, bytes32) {
        IBLSApkRegistry.PubkeyRegistrationParams memory blsKeyPair = _generateBlsPubkeyParams(privateKey);

        ValidatorRegistrationParams memory params;
        params.pubkeyG1 = blsKeyPair.pubkeyG1;
        params.pubkeyG2 = blsKeyPair.pubkeyG2;
        params.delegatePubKey = delegatePubKey;
        params.salt = bytes32(uint256(2));
        params.expiry = block.timestamp + 1 days;

        BN254.G1Point memory messagePoint = avsManager.blsMessageHash(
            avsManager.VALIDATOR_REGISTRATION_TYPEHASH(), params.delegatePubKey, params.salt, params.expiry
        );
        params.registrationSignature = messagePoint.scalar_mul(privateKey);

        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);
        mockEigenPodManager.createPod(podOwner);
        mockEigenPodManager.setValidatorStatus(podOwner, pubkeyHash, IEigenPod.VALIDATOR_STATUS.ACTIVE);

        return (params, pubkeyHash);
    }

    // BEGIN TESTS

    function testInitialize() public {
        // Add appropriate initialization checks here
        assertTrue(address(avsManager) != address(0));
    }

    function testRegisterOperator() public {
        _setupOperator();
        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));
        _registerOperator();
        assertTrue(mockAVSDirectory.isOperatorRegistered(operator));
    }

    function testRegisterValidator() public returns (bytes32) {
        _setupOperator();
        _registerOperator();

        uint256 privateKey = 123456; // This is a dummy private key for testing purposes
        bytes memory delegatePubKey = abi.encodePacked(uint256(1));
        bytes32 pubkeyHash = _registerValidator(privateKey, delegatePubKey);

        ValidatorData memory validatorData = avsManager.getValidator(pubkeyHash);
        assertEq(validatorData.delegatePubKey, delegatePubKey);

        return pubkeyHash;
    }

    function testDeregisterValidator() public {
        bytes32[] memory pubkeyHashes = new bytes32[](1);

        pubkeyHashes[0] = testRegisterValidator();

        vm.startPrank(operator);
        avsManager.deregisterValidator(pubkeyHashes);

        OperatorData memory operatorData = avsManager.getOperator(operator);
        assertEq(operatorData.validatorCount, 0);
    }

    function testDeregisterOperator() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            ISignatureUtils.SignatureWithSaltAndExpiry({ signature: new bytes(0), salt: bytes32(0), expiry: 0 });
        mockAVSDirectory.registerOperatorToAVS(operator, operatorSignature);

        // Test
        vm.prank(operator);
        avsManager.deregisterOperator();

        assertFalse(mockAVSDirectory.isOperatorRegistered(operator));
    }
}

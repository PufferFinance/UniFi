// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "eigenlayer/interfaces/IDelegationManager.sol";
import "eigenlayer/interfaces/ISlasher.sol";
import "eigenlayer/interfaces/ISignatureUtils.sol";
import "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import "eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";

contract Operator is Ownable {
    using Address for address;
    using ECDSA for bytes32;

    address public immutable podOwner;
    address public immutable avsManager;
    IDelegationManager public immutable EIGEN_DELEGATION_MANAGER;
    ISlasher public immutable EIGEN_SLASHER;

    mapping(bytes32 => address) private hashSigners;

    event SignatureProofUpdated(bytes32 indexed digestHash, address indexed signer);

    constructor(
        address _podOwner,
        address _avsManager,
        IDelegationManager _eigenDelegationManager,
        ISlasher _eigenSlasher
    ) {
        podOwner = _podOwner;
        avsManager = _avsManager;
        EIGEN_DELEGATION_MANAGER = _eigenDelegationManager;
        EIGEN_SLASHER = _eigenSlasher;
        _transferOwnership(_podOwner);
    }

    function registerToAVS(
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external onlyOwner {
        (bool success, ) = avsManager.call(
            abi.encodeWithSignature(
                "registerOperatorToAVS(address,bytes,string,tuple(uint256[2],uint256[2],uint256[2]),tuple(bytes,bytes32,uint256))",
                address(this),
                quorumNumbers,
                socket,
                params,
                operatorSignature
            )
        );
        require(success, "Registration to AVS failed");
    }

    function updateSignatureProof(bytes32 digestHash, address signer) external onlyOwner {
        hashSigners[digestHash] = signer;
        emit SignatureProofUpdated(digestHash, signer);
    }

    function isValidSignature(bytes32 digestHash, bytes calldata signature) external view returns (bytes4) {
        address signer = hashSigners[digestHash];

        if (signer != address(0) && digestHash.recover(signature) == signer) {
            return 0x1626ba7e; // EIP-1271 magic value for valid signatures
        } else {
            return 0xffffffff; // EIP-1271 magic value for invalid signatures
        }
    }

    function modifyOperatorDetails(IDelegationManager.OperatorDetails calldata newOperatorDetails) external onlyOwner {
        EIGEN_DELEGATION_MANAGER.modifyOperatorDetails(newOperatorDetails);
    }

    function updateOperatorMetadataURI(string calldata metadataURI) external onlyOwner {
        EIGEN_DELEGATION_MANAGER.updateOperatorMetadataURI(metadataURI);
    }

    function optIntoSlashing(address slasher) external onlyOwner {
        EIGEN_SLASHER.optIntoSlashing(slasher);
    }

    function deregisterFromAVS(bytes calldata quorumNumbers) external onlyOwner {
        (bool success, ) = avsManager.call(
            abi.encodeWithSignature(
                "deregisterOperatorFromAVS(address,bytes)",
                address(this),
                quorumNumbers
            )
        );
        require(success, "Deregistration from AVS failed");
    }

    function updateAVSSocket(string calldata socket) external onlyOwner {
        (bool success, ) = avsManager.call(
            abi.encodeWithSignature(
                "updateOperatorAVSSocket(address,string)",
                address(this),
                socket
            )
        );
        require(success, "Updating AVS socket failed");
    }

    function customCall(address target, bytes calldata customCalldata) external onlyOwner returns (bytes memory) {
        return target.functionCall(customCalldata);
    }
}

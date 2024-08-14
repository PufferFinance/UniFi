// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "eigenlayer/interfaces/IDelegationManager.sol";
import "eigenlayer/interfaces/ISlasher.sol";
import "eigenlayer/interfaces/ISignatureUtils.sol";
import "eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";

interface IOperator {
    function podOwner() external view returns (address);
    function avsManager() external view returns (address);
    function EIGEN_DELEGATION_MANAGER() external view returns (IDelegationManager);
    function EIGEN_SLASHER() external view returns (ISlasher);

    function registerToAVS(
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function updateSignatureProof(bytes32 digestHash, address signer) external;
    function isValidSignature(bytes32 digestHash, bytes calldata signature) external view returns (bytes4);
    function modifyOperatorDetails(IDelegationManager.OperatorDetails calldata newOperatorDetails) external;
    function updateOperatorMetadataURI(string calldata metadataURI) external;
    function optIntoSlashing(address slasher) external;
    function deregisterFromAVS(bytes calldata quorumNumbers) external;
    function updateAVSSocket(string calldata socket) external;
}

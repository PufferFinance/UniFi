// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IAVSDirectory.sol";
import "eigenlayer/interfaces/ISignatureUtils.sol";

contract MockAVSDirectory {
    mapping(address => bool) public registeredOperators;

    function avsOperatorStatus(address, address operator)
        external
        view
        returns (IAVSDirectory.OperatorAVSRegistrationStatus)
    {
        return registeredOperators[operator]
            ? IAVSDirectory.OperatorAVSRegistrationStatus.REGISTERED
            : IAVSDirectory.OperatorAVSRegistrationStatus.UNREGISTERED;
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        registeredOperators[operator] = true;
    }

    function deregisterOperatorFromAVS(address operator) external {
        registeredOperators[operator] = false;
    }

    // Mock function to check if an operator is registered
    function isOperatorRegistered(address operator) external view returns (bool) {
        return registeredOperators[operator];
    }

    // Mock function to calculate the operator AVS registration digest hash
    function calculateOperatorAVSRegistrationDigestHash(address operator, address avs, bytes32 salt, uint256 expiry)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(operator, avs, salt, expiry));
    }

    // Implement other functions from IAVSDirectory as needed for testing
}

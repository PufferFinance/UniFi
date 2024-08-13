// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IAVSDirectory.sol";
import "eigenlayer/interfaces/ISignatureUtils.sol";

contract MockAVSDirectory is IAVSDirectory {
    mapping(address => bool) public registeredOperators;

    function registerOperatorToAVS(address operator, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external {
        registeredOperators[operator] = true;
    }

    function deregisterOperatorFromAVS(address operator) external {
        registeredOperators[operator] = false;
    }

    // Mock function to check if an operator is registered
    function isOperatorRegistered(address operator) external view returns (bool) {
        return registeredOperators[operator];
    }

    // Implement other functions from IAVSDirectory as needed for testing
}

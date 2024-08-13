// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IDelegationManager.sol";

contract MockDelegationManager {
    mapping(address => bool) public operators;
    mapping(address => address) public delegations;

    function isOperator(address operator) external view returns (bool) {
        return operators[operator];
    }

    function delegatedTo(address podOwner) external view returns (address) {
        return delegations[podOwner];
    }

    // Mock function to set an operator for testing
    function setOperator(address operator, bool isActive) external {
        operators[operator] = isActive;
    }

    // Mock function to set a delegation for testing
    function setDelegation(address podOwner, address delegatee) external {
        delegations[podOwner] = delegatee;
    }

    // Implement other functions from IDelegationManager as needed for testing
}

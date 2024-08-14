// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPod.sol";

contract MockEigenPod is IEigenPod {
    mapping(bytes32 => VALIDATOR_STATUS) public validatorStatuses;
    mapping(bytes32 => mapping(uint64 => bool)) public provenWithdrawals;
    address owner;

    function setValidatorStatus(bytes32 pubkeyHash, VALIDATOR_STATUS status) external {
        validatorStatuses[pubkeyHash] = status;
    }

    function validatorStatus(bytes32 pubkeyHash) external view returns (VALIDATOR_STATUS) {
        return validatorStatuses[pubkeyHash];
    }

    constructor(address _owner) {
        owner = _owner;
    }

    // Implement required functions with minimal functionality
    function MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR() external pure returns (uint64) {
        return 0;
    }

    function activateRestaking() external { }

    function eigenPodManager() external pure returns (IEigenPodManager) {
        return IEigenPodManager(address(0));
    }

    function hasRestaked() external pure returns (bool) {
        return false;
    }

    function initialize(address) external { }

    function mostRecentWithdrawalTimestamp() external pure returns (uint64) {
        return 0;
    }

    function nonBeaconChainETHBalanceWei() external pure returns (uint256) {
        return 0;
    }

    function podOwner() external view returns (address) {
        return owner;
    }

    function provenWithdrawal(bytes32 validatorPubkeyHash, uint64 slot) external view returns (bool) {
        return provenWithdrawals[validatorPubkeyHash][slot];
    }

    function recoverTokens(IERC20[] memory, uint256[] memory, address) external { }
    function stake(bytes calldata, bytes calldata, bytes32) external payable { }

    function validatorPubkeyHashToInfo(bytes32 pubkeyHash) external view returns (ValidatorInfo memory) {
        return ValidatorInfo(0, 0, 0, validatorStatuses[pubkeyHash]);
    }

    function validatorPubkeyToInfo(bytes calldata) external pure returns (ValidatorInfo memory) {
        return ValidatorInfo(0, 0, 0, VALIDATOR_STATUS.INACTIVE);
    }

    function validatorStatus(bytes calldata) external pure returns (VALIDATOR_STATUS) {
        return VALIDATOR_STATUS.INACTIVE;
    }

    function withdrawBeforeRestaking() external { }
    function withdrawNonBeaconChainETHBalanceWei(address, uint256) external { }
    function withdrawRestakedBeaconChainETH(address, uint256) external { }

    function withdrawableRestakedExecutionLayerGwei() external pure returns (uint64) {
        return 0;
    }

    // Implement the missing functions
    function verifyAndProcessWithdrawals(
        uint64,
        BeaconChainProofs.StateRootProof calldata,
        BeaconChainProofs.WithdrawalProof[] calldata,
        bytes[] calldata,
        bytes32[][] calldata,
        bytes32[][] calldata
    ) external { }

    function verifyBalanceUpdates(
        uint64,
        uint40[] calldata,
        BeaconChainProofs.StateRootProof calldata,
        bytes[] calldata,
        bytes32[][] calldata
    ) external { }

    function verifyWithdrawalCredentials(
        uint64,
        BeaconChainProofs.StateRootProof calldata,
        uint40[] calldata,
        bytes[] calldata,
        bytes32[][] calldata
    ) external { }

    // Add a function to set proven withdrawals for testing
    function setProvenWithdrawal(bytes32 validatorPubkeyHash, uint64 slot, bool proven) external {
        provenWithdrawals[validatorPubkeyHash][slot] = proven;
    }
}

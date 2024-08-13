// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "eigenlayer/interfaces/IEigenPod.sol";

contract MockEigenPod is IEigenPod {
    mapping(bytes32 => VALIDATOR_STATUS) public validatorStatuses;

    function setValidatorStatus(bytes32 pubkeyHash, VALIDATOR_STATUS status) external {
        validatorStatuses[pubkeyHash] = status;
    }

    function validatorStatus(bytes32 pubkeyHash) external view returns (VALIDATOR_STATUS) {
        return validatorStatuses[pubkeyHash];
    }

    // Implement other required functions with minimal functionality
    function MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR() external pure returns (uint64) { return 0; }
    function activateRestaking() external {}
    function eigenPodManager() external pure returns (IEigenPodManager) { return IEigenPodManager(address(0)); }
    function hasRestaked() external pure returns (bool) { return false; }
    function initialize(address) external {}
    function mostRecentWithdrawalTimestamp() external pure returns (uint64) { return 0; }
    function nonBeaconChainETHBalanceWei() external pure returns (uint256) { return 0; }
    function podOwner() external pure returns (address) { return address(0); }
    function provenWithdrawal(bytes32, uint64) external pure returns (bool) { return false; }
    function recoverTokens(IERC20[] memory, uint256[] memory, address) external {}
    function stake(bytes calldata, bytes calldata, bytes32) external payable {}
    function validatorPubkeyHashToInfo(bytes32) external pure returns (ValidatorInfo memory) { return ValidatorInfo(0, 0); }
    function validatorPubkeyToInfo(bytes calldata) external pure returns (ValidatorInfo memory) { return ValidatorInfo(0, 0); }
    function validatorStatus(bytes calldata) external pure returns (VALIDATOR_STATUS) { return VALIDATOR_STATUS.INACTIVE; }
    function verifyAndProcessWithdrawals(bytes calldata, bytes[] calldata, bytes[] calldata) external {}
    function verifyBalanceUpdates(bytes calldata, bytes[] calldata, bytes[] calldata) external {}
    function verifyWithdrawalCredentials(bytes calldata, bytes calldata, bytes32) external pure returns (bool) { return false; }
    function withdrawBeforeRestaking() external {}
    function withdrawNonBeaconChainETHBalanceWei(address, uint256) external {}
    function withdrawRestakedBeaconChainETH(address, uint256) external {}
    function withdrawableRestakedExecutionLayerGwei() external pure returns (uint64) { return 0; }
}

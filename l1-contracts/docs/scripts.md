# UniFiAVSScripts Usage Guidelines

This document provides guidelines on how to use the UniFiAVSScripts and its functions for interacting with the UniFiAVSManager contract.

## Setup

Before running any scripts, ensure that you have:

1. Deployed the necessary contracts (UniFiAVSManager, MockEigenPodManager, MockDelegationManager).
2. Updated the contract addresses in the UniFiAVSScripts.sol file.

## Running Scripts

To run a script, use the following command format:

```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "functionName(parameters)" "parameter1" "parameter2" ...
```

Replace `functionName` with the desired function and provide the necessary parameters.

## Available Functions

### 1. createEigenPod(address podOwner)

Creates a mock EigenPod for the specified podOwner.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "createEigenPod(address)" "0x1234..."
```

### 2. addValidatorsToEigenPod(address podOwner, bytes32[] memory pubkeyHashes, MockEigenPod.ValidatorInfo[] memory validators)

Adds validators to the MockEigenPod for the specified podOwner.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsToEigenPod(address,bytes32[],tuple[])" "0x1234..." '["0xabcd...","0xefgh..."]' '[{"status":1,"validatorIndex":0},{"status":1,"validatorIndex":1}]'
```

### 3. registerValidatorsToUniFiAVS(address podOwner, bytes32[] memory blsPubKeyHashes)

Registers validators with the UniFiAVSManager.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerValidatorsToUniFiAVS(address,bytes32[])" "0x1234..." '["0xabcd...","0xefgh..."]'
```

### 4. registerOperatorToUniFiAVS(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)

Registers an operator with the UniFiAVSManager.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerOperatorToUniFiAVS((bytes,bytes32,uint256))" '["0xsignature...","0xsalt...",1234567890]'
```

### 5. delegateFromPodOwner(address podOwner, address operator)

Delegates from the podOwner to the operator using MockDelegationManager.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwner(address,address)" "0x1234..." "0x5678..."
```

### 6. setOperatorDelegateKey(bytes memory newDelegateKey)

Sets the operator's delegate key.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setOperatorDelegateKey(bytes)" "0xnewkey..."
```

### 7. startDeregisterOperator()

Starts the process of deregistering an operator.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "startDeregisterOperator()"
```

### 8. finishDeregisterOperator()

Finishes the process of deregistering an operator.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "finishDeregisterOperator()"
```

### 9. setupPodAndRegisterValidators(address podOwner, address operator, bytes32[] memory pubkeyHashes, MockEigenPod.ValidatorInfo[] memory validators, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)

Performs the complete process of setting up a pod, adding validators, delegating to an operator, registering the operator, and registering the validators.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setupPodAndRegisterValidators(address,address,bytes32[],tuple[],(bytes,bytes32,uint256))" "0x1234..." "0x5678..." '["0xabcd...","0xefgh..."]' '[{"status":1,"validatorIndex":0},{"status":1,"validatorIndex":1}]' '["0xsignature...","0xsalt...",1234567890]'
```

## Notes

- Ensure that you have the necessary permissions to execute these functions.
- Some functions may require specific roles or conditions to be met (e.g., being an operator, having a pod, etc.).
- Always verify the transaction details before confirming, especially when interacting with mainnet or important testnet deployments.
- These scripts are primarily for testing and demonstration purposes. Exercise caution when using them in a production environment.

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

### 4. registerOperatorToUniFiAVS(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature, OperatorCommitment memory initialCommitment)

Registers an operator with the UniFiAVSManager and sets the initial commitment.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerOperatorToUniFiAVS((bytes,bytes32,uint256),(bytes,uint256))" '["0xsignature...","0xsalt...",1234567890]' '["0xdelegateKey...",42]'
```

### 5. delegateFromPodOwner(address podOwner, address operator)

Delegates from the podOwner to the operator using MockDelegationManager.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwner(address,address)" "0x1234..." "0x5678..."
```

### 6. setOperatorCommitment(OperatorCommitment memory newCommitment)

Sets the operator's commitment.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setOperatorCommitment((bytes,uint256))" '["0xnewDelegateKey...",42]'
```

### 7. updateOperatorCommitment()

Updates the operator's commitment after the delay period.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "updateOperatorCommitment()"
```

### 8. startDeregisterOperator()

Starts the process of deregistering an operator.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "startDeregisterOperator()"
```

### 9. finishDeregisterOperator()

Finishes the process of deregistering an operator.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "finishDeregisterOperator()"
```

### 10. setupPodAndRegisterValidators(address podOwner, address operator, OperatorCommitment memory initialCommitment, bytes32[] memory pubkeyHashes, MockEigenPod.ValidatorInfo[] memory validators, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)

Performs the complete process of setting up a pod, adding validators, delegating to an operator, registering the operator, and registering the validators.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setupPodAndRegisterValidators(address,address,(bytes,uint256),bytes32[],tuple[],(bytes,bytes32,uint256))" "0x1234..." "0x5678..." '["0xdelegateKey...",42]' '["0xabcd...","0xefgh..."]' '[{"status":1,"validatorIndex":0},{"status":1,"validatorIndex":1}]' '["0xsignature...","0xsalt...",1234567890]'
```

### 11. addValidatorsFromJsonFile(string memory filePath, address podOwner)

Adds validators from a JSON file and registers them with UniFiAVSManager. The JSON file should follow the format of the Ethereum Beacon Chain API response for the `/eth/v1/beacon/states/head/validators` endpoint.

JSON Schema:
```json
{
  "execution_optimistic": boolean,
  "finalized": boolean,
  "data": [
    {
      "index": string,
      "balance": string,
      "status": string,
      "validator": {
        "pubkey": string,
        "withdrawal_credentials": string,
        "effective_balance": string,
        "slashed": boolean,
        "activation_eligibility_epoch": string,
        "activation_epoch": string,
        "exit_epoch": string,
        "withdrawable_epoch": string
      }
    }
  ]
}
```

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsFromJsonFile(string,address)" "path/to/validators.json" "0x1234..."
```

Note: Ensure that the JSON file contains the validator data in the format specified above, which is typically obtained from the Ethereum Beacon Chain API.

### 12. addValidatorsDirectly(address podOwner, bytes[] memory pubkeys, uint64[] memory validatorIndices)

Adds validators directly by passing their public keys and validator indices. This function allows you to add validators without using a JSON file.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsDirectly(address,bytes[],uint64[])" "0x1234..." '["0xpubkey1...","0xpubkey2..."]' '[1,2]'
```

Note: Ensure that the `pubkeys` and `validatorIndices` arrays have the same length and correspond to each other.

## Notes

- Ensure that you have the necessary permissions to execute these functions.
- Some functions may require specific roles or conditions to be met (e.g., being an operator, having a pod, etc.).
- Always verify the transaction details before confirming, especially when interacting with mainnet or important testnet deployments.
- These scripts are primarily for testing and demonstration purposes. Exercise caution when using them in a production environment.

# UniFiAVSScripts Usage Guidelines

This document provides guidelines on how to use the UniFiAVSScripts and its functions for interacting with the UniFiAVSManager contract.

## Setup

Before running any scripts, ensure that you have:

1. Deployed the necessary contracts:
   - For Helder chain: UniFiAVSManager, MockEigenPodManager, MockDelegationManager, MockAVSDirectory
   - For other chains (e.g., Holesky, Mainnet): UniFiAVSManager, EigenPodManager, DelegationManager, AVSDirectory
2. Updated the contract addresses in the UniFiAVSScripts.sol file for both Helder and non-Helder chains.
3. Set the correct chain ID for the Helder chain in the setUp function.

## Running Scripts

To run a script, use the following command format:

```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "functionName(parameters)" "parameter1" "parameter2" ...
```

Replace `functionName` with the desired function and provide the necessary parameters.

## Available Functions

### Helder-only Functions

1. createEigenPod(address podOwner)
   - Creates a mock EigenPod for the specified podOwner.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "createEigenPod(address)" "0x1234..."`

2. addValidatorsToEigenPod(address podOwner, bytes32[] memory pubkeyHashes, IEigenPod.ValidatorInfo[] memory validators)
   - Adds validators to the MockEigenPod for the specified podOwner.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsToEigenPod(address,bytes32[],tuple[])" "0x1234..." '["0xabcd...","0xefgh..."]' '[{"status":1,"validatorIndex":0},{"status":1,"validatorIndex":1}]'`

3. delegateFromPodOwner(address podOwner, address operator)
   - Delegates from PodOwner to Operator using MockDelegationManager.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwner(address,address)" "0x1234..." "0x5678..."`

4. delegateFromPodOwner(address podOwner, address operator, SignatureWithExpiry memory approverSignatureAndExpiry, bytes32 approverSalt)
   - Delegates from PodOwner to Operator with signature.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwner(address,address,(bytes,uint256),bytes32)" "0x1234..." "0x5678..." '["0xsignature...",1234567890]' "0xsalt..."`

5. addValidatorsFromJsonFile(string memory filePath, address podOwner)
   - Adds validators from a JSON file and registers them with UniFiAVSManager.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsFromJsonFile(string,address)" "path/to/validators.json" "0x1234..."`

6. addValidatorsToEigenPodAndRegisterToAVS(address podOwner, bytes[] memory pubkeys, uint64[] memory validatorIndices)
   - Adds validators directly to EigenPod and registers them with UniFiAVSManager.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "addValidatorsToEigenPodAndRegisterToAVS(address,bytes[],uint64[])" "0x1234..." '["0xpubkey1...","0xpubkey2..."]' '[1,2]'`

7. setupPodAndRegisterValidatorsFromJsonFile(uint256 signerPk, address podOwner, OperatorCommitment memory initialCommitment, string memory filePath)
   - Sets up a pod and registers validators from a JSON file.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setupPodAndRegisterValidatorsFromJsonFile(uint256,address,(bytes,uint256),string)" 123456 "0x1234..." '["0xdelegateKey...",42]' "path/to/validators.json"`

8. setupPodAndRegisterValidators(uint256 signerPk, address podOwner, OperatorCommitment memory initialCommitment, bytes[] memory pubkeys, uint64[] memory validatorIndices)
   - Sets up a pod and registers validators directly.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setupPodAndRegisterValidators(uint256,address,(bytes,uint256),bytes[],uint64[])" 123456 "0x1234..." '["0xdelegateKey...",42]' '["0xpubkey1...","0xpubkey2..."]' '[1,2]'`

### Non-Helder Functions

9. registerAsOperator(OperatorDetails memory registeringOperatorDetails, string memory metadataURI)
   - Registers the caller as an operator in the DelegationManager contract.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerAsOperator((address,address,uint32,uint32,uint96,uint96,bool,uint256[]),string)" '["0xoperatorAddress","0xearningsReceiverAddress",1000,2000,1000000000000000000,2000000000000000000,true,[1,2,3]]' "https://metadata.uri"`

### Common Functions (Both Helder and Non-Helder)

10. registerValidatorsToUniFiAVS(address podOwner, bytes32[] memory blsPubKeyHashes)
    - Registers validators with the UniFiAVSManager using pre-hashed public keys.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerValidatorsToUniFiAVS(address,bytes32[])" "0x1234..." '["0xabcd...","0xefgh..."]'`

11. registerValidatorsToUniFiAVS(address podOwner, bytes[] memory pubkeys)
    - Registers validators with the UniFiAVSManager using raw public keys.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerValidatorsToUniFiAVS(address,bytes[])" "0x1234..." '["0xpubkey1...","0xpubkey2..."]'`

12. registerOperatorToUniFiAVS(uint256 signerPk, OperatorCommitment memory initialCommitment)
    - Registers an operator with the UniFiAVSManager and sets the initial commitment.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerOperatorToUniFiAVS(uint256,(bytes,uint256))" 123456 '["0xdelegateKey...",42]'`

13. registerOperatorToUniFiAVSWithDelegateKey(uint256 signerPk, bytes memory delegateKey)
    - Registers an operator with the UniFiAVSManager using only a delegate key.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerOperatorToUniFiAVSWithDelegateKey(uint256,bytes)" 123456 "0xdelegateKey..."`

14. delegateFromPodOwnerBySignature(address staker, address operator, SignatureWithExpiry memory stakerSignatureAndExpiry, SignatureWithExpiry memory approverSignatureAndExpiry, bytes32 approverSalt)
    - Delegates from PodOwner to Operator by signature.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwnerBySignature(address,address,(bytes,uint256),(bytes,uint256),bytes32)" "0x1234..." "0x5678..." '["0xstakerSignature...",1234567890]' '["0xapproverSignature...",1234567890]' "0xsalt..."`

15. setOperatorCommitment(OperatorCommitment memory newCommitment)
    - Sets the operator's commitment.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setOperatorCommitment((bytes,uint256))" '["0xnewDelegateKey...",42]'`

16. updateOperatorCommitment()
    - Updates the operator's commitment after the delay period.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "updateOperatorCommitment()"`

17. startDeregisterOperator()
    - Starts the process of deregistering an operator.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "startDeregisterOperator()"`

18. finishDeregisterOperator()
    - Finishes the process of deregistering an operator.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "finishDeregisterOperator()"`

19. deregisterValidatorFromUniFiAVS(address podOwner, bytes32 pubkeyHash)
    - Deregisters a validator from the UniFiAVSManager.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "deregisterValidatorFromUniFiAVS(address,bytes32)" "0x1234..." "0xpubkeyHash"`

## Notes

- Ensure that you have the necessary permissions to execute these functions.
- Some functions may require specific roles or conditions to be met (e.g., being an operator, having a pod, etc.).
- Always verify the transaction details before confirming, especially when interacting with mainnet or important testnet deployments.
- These scripts are primarily for testing and demonstration purposes. Exercise caution when using them in a production environment.

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

### 13. setupPodAndRegisterValidatorsDirectly(uint256 signerPk, address podOwner, OperatorCommitment memory initialCommitment, bytes[] memory pubkeys, uint64[] memory validatorIndices)

Performs the complete process of setting up a pod, adding validators directly, delegating to an operator, registering the operator, and registering the validators.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setupPodAndRegisterValidatorsDirectly(uint256,address,(bytes,uint256),bytes[],uint64[])" "123456" "0x1234..." '["0xdelegateKey...",42]' '["0xpubkey1...","0xpubkey2..."]' '[1,2]'
```

Note: This function combines the steps of creating a pod, registering an operator, and adding validators directly, making it a convenient option for setting up the entire process in one transaction.

### 14. registerAsOperator(OperatorDetails memory registeringOperatorDetails, string memory metadataURI)

Registers the caller as an operator in the DelegationManager contract. This function is only available for non-Helder chains.

Usage:
```
forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "registerAsOperator((address,address,uint32,uint32,uint96,uint96,bool,uint256[]),string)" '["0xoperatorAddress","0xearningsReceiverAddress",1000,2000,1000000000000000000,2000000000000000000,true,[1,2,3]]' "https://metadata.uri"
```

Note: The `registeringOperatorDetails` parameter is a struct containing the operator's details, and `metadataURI` is a string pointing to the operator's metadata.

## Notes

- Ensure that you have the necessary permissions to execute these functions.
- Some functions may require specific roles or conditions to be met (e.g., being an operator, having a pod, etc.).
- Always verify the transaction details before confirming, especially when interacting with mainnet or important testnet deployments.
- These scripts are primarily for testing and demonstration purposes. Exercise caution when using them in a production environment.

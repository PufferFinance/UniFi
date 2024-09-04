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

## Understanding OperatorCommitment and chainIdBitMap

The OperatorCommitment is a struct that contains two important pieces of information:
1. delegateKey: A bytes array representing the delegate key for the operator.
2. chainIDBitMap: A uint256 representing the chains the operator is committed to serve.

The chainIdBitMap is a bitmap where each bit represents a specific chain ID. If a bit is set to 1, it means the operator is committed to serving that chain. The mapping between bit positions and chain IDs is maintained separately in the UniFiAVSManager contract.

Examples:
- chainIdBitMap = 3 (binary: 0011): The operator is committed to chains with IDs at positions 0 and 1.
- chainIdBitMap = 6 (binary: 0110): The operator is committed to chains with IDs at positions 1 and 2.
- chainIdBitMap = 15 (binary: 1111): The operator is committed to chains with IDs at positions 0, 1, 2, and 3.

When setting or updating an operator's commitment, you need to provide both the delegateKey and the chainIdBitMap.

## Deregistration Delay

The UniFiAVSManager implements a deregistration delay mechanism for security purposes. This delay is a period that must pass before certain actions (like deregistering an operator or updating commitments) can be completed.

Functions affected by the deregistration delay:
- finishDeregisterOperator(): Can only be called after the delay period since startDeregisterOperator() was called.
- updateOperatorCommitment(): Updates the operator's commitment after the delay period since setOperatorCommitment() was called.

The length of the delay is configurable and can be queried using the getDeregistrationDelay() function.

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

4. delegateFromPodOwner(address operator, ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry, bytes32 approverSalt)
   - Delegates from PodOwner to Operator with signature.
   - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwner(address,(bytes,uint256),bytes32)" "0x5678..." '["0xsignature...",1234567890]' "0xsalt..."`

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

9. registerAsOperator(IDelegationManager.OperatorDetails memory registeringOperatorDetails, string memory metadataURI)
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

14. delegateFromPodOwnerBySignature(address staker, address operator, ISignatureUtils.SignatureWithExpiry memory stakerSignatureAndExpiry, ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry, bytes32 approverSalt)
    - Delegates from PodOwner to Operator by signature.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "delegateFromPodOwnerBySignature(address,address,(bytes,uint256),(bytes,uint256),bytes32)" "0x1234..." "0x5678..." '["0xstakerSignature...",1234567890]' '["0xapproverSignature...",1234567890]' "0xsalt..."`

15. setOperatorCommitment(OperatorCommitment memory newCommitment)
    - Sets the operator's commitment.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "setOperatorCommitment((bytes,uint256))" '["0xnewDelegateKey...",42]'`
    - Note: This initiates the commitment change process. The new commitment will not be active until updateOperatorCommitment() is called after the deregistration delay.

16. updateOperatorCommitment()
    - Updates the operator's commitment after the delay period.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "updateOperatorCommitment()"`
    - Note: This can only be called after the deregistration delay has passed since setOperatorCommitment() was called.

17. startDeregisterOperator()
    - Starts the process of deregistering an operator.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "startDeregisterOperator()"`

18. finishDeregisterOperator()
    - Finishes the process of deregistering an operator.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "finishDeregisterOperator()"`
    - Note: This can only be called after the deregistration delay has passed since startDeregisterOperator() was called.

19. deregisterValidatorFromUniFiAVS(address podOwner, bytes32 pubkeyHash)
    - Deregisters a validator from the UniFiAVSManager.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "deregisterValidatorFromUniFiAVS(address,bytes32)" "0x1234..." "0xpubkeyHash"`

20. updateOperatorCommitment(OperatorCommitment memory newCommitment)
    - Updates the operator's commitment in the UniFiAVSManager.
    - Usage: `forge script script/UniFiAVSScripts.sol:UniFiAVSScripts --sig "updateOperatorCommitment((bytes,uint256))" '["0xnewDelegateKey...",42]'`

## Notes

- Ensure that you have the necessary permissions to execute these functions.
- Some functions may require specific roles or conditions to be met (e.g., being an operator, having a pod, etc.).
- Always verify the transaction details before confirming, especially when interacting with mainnet or important testnet deployments.
- These scripts are primarily for testing and demonstration purposes. Exercise caution when using them in a production environment.
- Be aware of the deregistration delay when calling functions that involve deregistration or commitment updates. These actions may not take effect immediately.

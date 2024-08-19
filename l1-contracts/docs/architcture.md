
# Overview
UniFi AVS is composed of off-chain software for handling pre-conf operations, and on-chain contracts for handling registrations, rewards, and punishments.

The following diagram highlights how these components interact with each other:
> ![alt text](images/system-overview.png)

## Preconf Flow

The preconfirmation (preconf) flow in UniFi AVS involves several steps and interactions between different components of the system. The following sequence diagram illustrates this process:

![Preconf Flow Sequence Diagram](images/preconf-flow-sequence.mermaid)

Here's a detailed description of the preconf flow:

1. **Delegate Key Setup**: 
   - The operator sets their delegate key to point to a Gateway. This allows the Gateway to act on behalf of the operator for preconfirmation duties.

2. **Lookahead Window Query**:
   - The Gateway queries their associated BeaconNode to check the lookahead window.
   - The BeaconNode returns the validator indices of the upcoming proposers.

3. **Validator Registration Check**:
   - For each validator index received, the Gateway queries the UniFiAVSManager contract using the `getValidator` function.
   - This check confirms if the validators are registered to the AVS and if they have delegated to the Gateway.

4. **Preconf Processing**:
   - If the validators are registered and delegated, the Gateway starts receiving preconf transactions.
   - The Gateway signs preconfs with their delegate key.

5. **Block Proposal**:
   - When it's time to propose a block, the user (via Commit-Boost) requests the final L1 from the Gateway.
   - The Gateway provides the final L1 to Commit-Boost.
   - Commit-Boost uses this information to help the operator propose the block.

6. **Reward Distribution**:
   - After the block is proposed, the block rewards are split:
     - A portion is sent directly to the Gateway as compensation for their services.
     - The rest is sent to the RewardsManager contract.
   - The RewardsManager smooths out the rewards from multiple validators, ensuring a more consistent distribution over time.

This flow ensures that the preconfirmation process is efficient, secure, and properly incentivized. It leverages the strengths of different components in the UniFi AVS ecosystem, from the Gateway's ability to handle preconf duties to the RewardsManager's role in fair reward distribution.

## Node Software
The following diagram highlights system's main software components:
> ![alt text](images/component-overview.png)

UniFi AVS has a tight coupling with Commit-Boost, allowing validators to seamlessly participate in the preconfirmation process while maintaining their regular validation duties. Validators will run Commit-Boost alongside their standard validator stack. When they are ready to propose a block, they have the flexibility to choose how they want to handle their preconfirmation responsibilities. Options include:

1. Self-build: The validator can use Commit-Boost to directly handle their preconfirmation responsibilities.
2. Delegate: The validator can use Commit-Boost to delegate their preconfirmation duties to another entity e.g., a sophisticated Gateway.

## Smart Contracts
### `UniFiAVSManager` - AVS Registrations
#### Operator Registration
At a high level it is required for an `Operator` within the EigenLayer contracts to opt-in to the AVS. See the [Operator Registration Process](registration.md#operator-registration-process) section for more details.

#### Delegate Key Registration
Each `Operator` will register a single `delegateKey` that will be used to issue preconfs. See the [Delegate Key Registration](registration.md#delegate-key-registration) section for more details.

#### Validator Registration
If an EigenPod owner has delegated their stake to an `Operator`, then the `Operator` can register the EigenPod's validators as preconferers in the AVS. See the [Validator Registration](registration.md#validator-registration) section for more details.

> **Aside on Neutrality**: In the spirit of neutrality, it is important to keep preconf registrations credibly neutral. As such, the Ethereum community is working to launch a permissionless registry contract that exists outside of any protocols (i.e., outside of Puffer or EigenLayer). To prevent fragmentation, the `UniFiAVSManager` contract will look to this registry as a primary source when validators register, and revert if the validator is not opted-in.

### `RewardsManager` - Rewards Distribution

The rewards distribution in UniFi AVS is designed to provide a consistent and attractive incentive structure for participating validators. Key features of the rewards system include:

1. preconf fees
2. MEV-smoothing mechanism
3. Ether-only payouts
4. Competitive earnings potential

For a comprehensive overview of the rewards distribution system, including its key features, benefits, and impact on the Ethereum ecosystem, see the [Rewards Distribution](rewards.md) document.

### `DisputeManager` - Slashing
UniFi AVS implements slashing to ensure the integrity of the preconfirmation process. This mechanism is designed to penalize validators who break their preconfirmation promises or fail to fulfill their duties.

The slashing mechanism consists of two main components:

1. Safety Faults: Penalties for breaking preconfirmation promises.
2. Liveness Faults: Penalties for missing block proposals.
3. Rewards Stealing: Penalties for 'Rug-Pooling'.

For a detailed explanation of the slashing mechanism, including the types of faults, the slashing process, and future developments, please refer to the [Slashing Mechanism](slashing.md) document.


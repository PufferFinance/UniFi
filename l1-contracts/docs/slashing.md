# Slashing Mechanism

The slashing mechanism in UniFi AVS is designed to ensure the integrity of the pre-confirmation process. It consists of two main cases:

1. Safety Faults (Breaking Pre-confirmation Promises)
2. Liveness Faults (Missed Block Slashing)

## Safety Faults

Safety faults occur when a validator breaks their pre-conf promise. This category encompasses a larger design space compared to Liveness faults, including:

a) Inclusion Pre-conf Violations
b) Execution Pre-conf Violations

## Liveness Faults

Liveness faults occur when a validator signs off on pre-confirmations for their upcoming block but fails to submit a block during their assigned slot.

## Slashing Process

The slashing process involves two key components:

1. DisputeManager: Where proofs of pre-confirmation violations are submitted.
2. EigenLayer Slasher: Responsible for executing the slashing action.

When a violation is detected and proven, the DisputeManager verifies the proof and calls `Slasher.freezeOperator()` on EigenLayer to freeze the operator's stake.

As EigenLayer's slashing capabilities evolve, UniFi AVS will update its slashing mechanism to take full advantage of these features, potentially including partial stake deductions for violations.

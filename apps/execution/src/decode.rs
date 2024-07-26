use crate::UnifiContractEvents;
use alloy_sol_types::SolEventInterface;
use reth_execution_types::Chain;
use reth_primitives::{Address, SealedBlockWithSenders, TransactionSigned};

/// Decode chain of blocks into a flattened list of receipt logs, filter only transactions to the
/// Rollup contract [ROLLUP_CONTRACT_ADDRESS] and extract [RollupContractEvents].
pub fn decode_chain_into_rollup_events(
    chain: &Chain,
    rollup_contract: Address
) -> Vec<(&SealedBlockWithSenders, &TransactionSigned, UnifiContractEvents)> {
    chain
        // Get all blocks and receipts
        .blocks_and_receipts()
        // Get all receipts
        .flat_map(|(block, receipts)| {
            block
                .body
                .iter()
                .zip(receipts.iter().flatten())
                .map(move |(tx, receipt)| (block, tx, receipt))
        })
        // Get all logs from rollup contract
        .flat_map(|(block, tx, receipt)| {
            receipt
                .logs
                .iter()
                .filter(|log| log.address == rollup_contract)
                .map(move |log| (block, tx, log))
        })
        // Decode and filter rollup events
        .filter_map(|(block, tx, log)| {
            UnifiContractEvents::decode_raw_log(log.topics(), &log.data.data, true)
                .ok()
                .map(|event| (block, tx, event))
        })
        .collect()
}

// todo unit tests
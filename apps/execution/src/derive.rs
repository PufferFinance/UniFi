use alloy_consensus::{Blob, SidecarCoder, SimpleCoder};
use alloy_rlp::Decodable as _;
use reth_primitives::{
    eip4844::kzg_to_versioned_hash, keccak256, Address, Bytes, TransactionSigned, TxType, B256,
};
use reth_transaction_pool::TransactionPool;

/// Decode transactions from the block data and recover senders.
/// - If the transaction is a blob-carrying one, decode the blobs either using the local transaction
///   pool, or querying Blobscan.
/// - If the transaction is a regular one, decode the block data directly.
pub async fn derive_transactions<Pool: TransactionPool>(
    pool: &Pool,
    tx: &TransactionSigned,
    block_data: Bytes,
    block_data_hash: B256,
    chain_id: u64,
) -> eyre::Result<Vec<(TransactionSigned, Address)>> {
    // Get raw transactions either from the blobs, or directly from the block data
    let raw_transactions = if matches!(tx.tx_type(), TxType::Eip4844) {
        let blobs: Vec<_> = if let Some(sidecar) = pool.get_blob(tx.hash)? {
            // Try to get blobs from the transaction pool
            sidecar.blobs.into_iter().zip(sidecar.commitments).collect()
        } else {
            // If transaction is not found in the pool, try to get blobs from Blobscan
            let blobscan_client = foundry_blob_explorers::Client::holesky();
            let sidecar = blobscan_client.transaction(tx.hash).await?.blob_sidecar();
            sidecar
                .blobs
                .into_iter()
                .map(|blob| (*blob).into())
                .zip(
                    sidecar
                        .commitments
                        .into_iter()
                        .map(|commitment| (*commitment).into()),
                )
                .collect()
        };

        // Decode blob hashes from block data
        let blob_hashes = Vec::<B256>::decode(&mut block_data.as_ref())?;

        // Filter blobs that are present in the block data
        let blobs = blobs
            .into_iter()
            // Convert blob KZG commitments to versioned hashes
            .map(|(blob, commitment)| (blob, kzg_to_versioned_hash(commitment.as_slice())))
            // Filter only blobs that are present in the block data
            .filter(|(_, hash)| blob_hashes.contains(hash))
            .map(|(blob, _)| Blob::from(*blob))
            .collect::<Vec<_>>();
        if blobs.len() != blob_hashes.len() {
            eyre::bail!("some blobs not found")
        }

        // Decode blobs and concatenate them to get the raw transactions
        let data = SimpleCoder::default()
            .decode_all(&blobs)
            .ok_or(eyre::eyre!("failed to decode blobs"))?
            .concat();

        data.into()
    } else {
        block_data
    };

    let raw_transaction_hash = keccak256(&raw_transactions);
    if raw_transaction_hash != block_data_hash {
        eyre::bail!("block data hash mismatch")
    }

    // Decode block data, filter only transactions with the correct chain ID and recover senders
    let transactions = Vec::<TransactionSigned>::decode(&mut raw_transactions.as_ref())?
        .into_iter()
        .filter(|tx| tx.chain_id() == Some(chain_id))
        .map(|tx| {
            let sender = tx
                .recover_signer()
                .ok_or(eyre::eyre!("failed to recover signer"))?;
            Ok((tx, sender))
        })
        .collect::<eyre::Result<_>>()?;

    Ok(transactions)
}

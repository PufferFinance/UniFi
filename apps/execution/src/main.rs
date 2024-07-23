mod db;
mod execution;
mod unifi;

use alloy_sol_types::{sol, SolEventInterface, SolInterface};
use once_cell::sync::Lazy;
use reth_chainspec::{ChainSpec, ChainSpecBuilder};
use reth_node_ethereum::EthereumNode;
use reth_primitives::{address, Address, SealedBlockWithSenders, TransactionSigned, U256};
use reth_tracing::tracing::{error, info};
use rusqlite::Connection;
use std::sync::Arc;
use unifi::UnifiRollup;

sol! {
   // SPDX-License-Identifier: UNLICENSED
    pragma solidity ^0.8.0;

    contract UnifiContract {

        struct BlockHeader {
            uint256 unifiChainId;
            uint256 sequenceNum;
            uint256 gasLimit;
            bytes32 unifiBlockHash;
        }

        uint256 public genesisBlockNumber;

        mapping(uint256 => uint256) public lastRollupSubmissionBlock;
        mapping(uint256 => uint256) public lastSequenceNum;

        error OneRollupSubmissionPerBlock();
        error NonMonotonicSequenceNum(uint256 expected);

        event BlockSubmitted(
            uint256 indexed unifiChainId,
            uint256 gasLimit,
            bytes32 unifiBlockHash
        );

        constructor() {
            genesisBlockNumber = block.number;
        }

        function submitBlock(
            BlockHeader memory header,
            bytes calldata
        ) external {
            // assert that the sequence number is valid and increment it
            uint256 _sequenceNum = lastSequenceNum[header.unifiChainId]++;
            if (_sequenceNum != header.sequenceNum) revert NonMonotonicSequenceNum(_sequenceNum);
            // assert this is the first rollup block submitted for this host block
            if (lastRollupSubmissionBlock[header.unifiChainId] == block.number)
                revert OneRollupSubmissionPerBlock();
            lastRollupSubmissionBlock[header.unifiChainId] = block.number;

            // emit event
            emit BlockSubmitted(
                header.unifiChainId,
                header.gasLimit,
                header.unifiBlockHash
            );
        }
    }
}

use UnifiContract::{UnifiContractCalls, UnifiContractEvents};

const DATABASE_PATH: &str = "rollup.db";
const ROLLUP_SUBMITTER_ADDRESS: Address = address!("DDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0");
const CHAIN_ID: u64 = 17001;
static CHAIN_SPEC: Lazy<Arc<ChainSpec>> = Lazy::new(|| {
    Arc::new(
        ChainSpecBuilder::default()
            .chain(CHAIN_ID.into())
            .genesis(reth_primitives::Genesis::clique_genesis(
                CHAIN_ID,
                ROLLUP_SUBMITTER_ADDRESS,
            ))
            .shanghai_activated()
            .build(),
    )
});

fn main() -> eyre::Result<()> {
    reth::cli::Cli::parse_args().run(|builder, _| async move {
        let handle = builder
            .node(EthereumNode::default())
            .install_exex("UnifiRollup", move |ctx| async {
                let connection = Connection::open(DATABASE_PATH)?;
                Ok(UnifiRollup::new(ctx, connection)?.start())
            })
            .launch()
            .await?;

        handle.wait_for_node_exit().await
    })
}

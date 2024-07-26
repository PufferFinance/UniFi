mod unifi;
mod db;
mod execute;
mod derive;
mod decode;

use alloy_sol_types::{sol, SolEventInterface, SolInterface};
use once_cell::sync::Lazy;
use reth_chainspec::{ChainSpec, ChainSpecBuilder};
use reth_node_ethereum::EthereumNode;
use reth_primitives::{address, Address, SealedBlockWithSenders, TransactionSigned, U256};
use reth_tracing::tracing::{error, info};
use rusqlite::Connection;
use std::sync::Arc;
use unifi::UnifiRollup;

// forge inspect src/Unifi.sol:UnifiContract bytecode
// cp out/Unifi.sol/UnifiContract.json ../apps/execution/abi/
sol! {
    #[allow(missing_docs)]
    // solc v0.8.26; solc Counter.sol --via-ir --optimize --bin
    #[sol(rpc, bytecode="0x6080604052348015600e575f80fd5b50435f556102f68061001f5f395ff3fe608060405234801561000f575f80fd5b506004361061004a575f3560e01c80630356fe3a1461004e578063be5e78ba14610068578063e172c47814610087578063f4fca1de146100a6575b5f80fd5b6100565f5481565b60405190815260200160405180910390f35b610056610076366004610197565b60026020525f908152604090205481565b610056610095366004610197565b60016020525f908152604090205481565b6100b96100b43660046101f3565b6100bb565b005b82515f908152600260205260408120805490826100d78361029c565b919050559050836020015181146101085760405163215cd2a960e11b81526004810182905260240160405180910390fd5b83515f90815260016020526040902054439003610138576040516311521db560e11b815260040160405180910390fd5b83515f908152600160209081526040918290204390558551828701516060880151845191825292810192909252917ff5bf4c4c5cd6a5cd4ff7cd890e34c27b8c163f59ef0acecd903628a20ddd8569910160405180910390a250505050565b5f602082840312156101a7575f80fd5b5035919050565b5f8083601f8401126101be575f80fd5b50813567ffffffffffffffff8111156101d5575f80fd5b6020830191508360208285010111156101ec575f80fd5b9250929050565b5f805f83850360a0811215610206575f80fd5b6080811215610213575f80fd5b506040516080810181811067ffffffffffffffff8211171561024357634e487b7160e01b5f52604160045260245ffd5b604090815285358252602080870135908301528581013590820152606080860135908201529250608084013567ffffffffffffffff811115610283575f80fd5b61028f868287016101ae565b9497909650939450505050565b5f600182016102b957634e487b7160e01b5f52601160045260245ffd5b506001019056fea2646970667358221220e46dfc264081b565f2cf0d0b4d66b2046f06d04dd8c65d7104a9aad89f515b6764736f6c634300081a0033")]
    // SPDX-License-Identifier: GPL-3.0
    // pragma solidity ^0.8.0;

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

pub use UnifiContract::{UnifiContractCalls, UnifiContractEvents};

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

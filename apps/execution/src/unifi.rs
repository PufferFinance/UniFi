use crate::{db::Database, UnifiContract};
use reth_execution_types::Chain;
use reth_exex::{ExExContext, ExExEvent, ExExNotification};
use reth_node_api::FullNodeComponents;
use rusqlite::Connection;
use std::sync::Arc;
use tracing::info;

pub struct UnifiRollup<Node: FullNodeComponents> {
    ctx: ExExContext<Node>,
    db: Database,
}

impl<Node: FullNodeComponents> UnifiRollup<Node> {
    pub fn new(ctx: ExExContext<Node>, connection: Connection) -> eyre::Result<Self> {
        let db = Database::new(connection)?;
        Ok(Self { ctx, db })
    }

    pub async fn start(mut self) -> eyre::Result<()> {
        while let Some(notification) = self.ctx.notifications.recv().await {
            self.process_notification(&notification).await?;

            if let Some(committed_chain) = notification.committed_chain() {
                self.ctx
                    .events
                    .send(ExExEvent::FinishedHeight(committed_chain.tip().number))?;
            }
        }
        Ok(())
    }

    async fn process_notification(&mut self, notification: &ExExNotification) -> eyre::Result<()> {
        match notification {
            ExExNotification::ChainCommitted { new } => {
                self.handle_chain_committed(new).await?;
            }
            ExExNotification::ChainReorged { old, new } => {
                self.handle_chain_reorged(old, new).await?;
            }
            ExExNotification::ChainReverted { old } => {
                self.handle_chain_reverted(old).await?;
            }
        }
        Ok(())
    }

    async fn handle_chain_committed(&mut self, chain: &Arc<Chain>) -> eyre::Result<()> {
        // Implement chain commit logic
        info!(committed_chain = ?chain.range(), "Received commit");
        Ok(())
    }

    async fn handle_chain_reorged(
        &mut self,
        old: &Arc<Chain>,
        new: &Arc<Chain>,
    ) -> eyre::Result<()> {
        // Implement chain reorg logic
        info!(from_chain = ?old.range(), to_chain = ?new.range(), "Received reorg");
        Ok(())
    }

    async fn handle_chain_reverted(&mut self, old: &Arc<Chain>) -> eyre::Result<()> {
        // Implement chain revert logic
        info!(reverted_chain = ?old.range(), "Received revert");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use reth_chainspec::HOLESKY;
    use reth_exex_test_utils::PollOnce;

    use futures::Future;
    use rand::rngs::ThreadRng;
    use reth::{
        blockchain_tree::noop::NoopBlockchainTree, builder::{components::Components, NodeAdapter, NodeConfig}, network::{config::SecretKey, NetworkConfigBuilder, NetworkManager}, payload::noop::NoopPayloadBuilderService, primitives::{
            Address, Block, Header, Log, Receipt, Transaction, TransactionSigned, TxKind, TxLegacy,
            TxType, U256,
        }, providers::{
            providers::BlockchainProvider,
            test_utils::create_test_provider_factory_with_chain_spec, BlockReader,
        }, revm::{db::BundleState, primitives::FixedBytes}, rpc::types::TransactionRequest, tasks::TaskManager, transaction_pool::test_utils::testing_pool
    };
    use reth_chainspec::{ChainSpec, Head};
    use reth_consensus::test_utils::TestConsensus;
    use reth_db_common::init::init_genesis;
    use reth_evm::test_utils::MockExecutorProvider;
    use reth_execution_types::{Chain, ExecutionOutcome};
    use reth_exex::ExExContext;
    use reth_exex_test_utils::{
        Adapter, TestExExHandle, TestNode,
    };
    use reth_node_api::FullNodeTypesAdapter;
    use reth_node_ethereum::{EthEngineTypes, EthEvmConfig};
    use reth_testing_utils::generators::{random_block, random_receipt, random_signed_tx};
    use rusqlite::Connection;
    use std::{pin::Pin, sync::Arc};
    use alloy_network::{EthereumWallet, ReceiptResponse, TransactionBuilder};

    use crate::{unifi::UnifiRollup, UnifiContract};

    pub struct TestUnifiRollup {
        chain_spec: Arc<ChainSpec>,
        port: u16,
    }

    impl TestUnifiRollup {
        pub fn new(chain_spec: Arc<ChainSpec>, port: u16) -> Self {
            Self { chain_spec, port }
        }

        pub async fn setup(
            &self,
        ) -> eyre::Result<(
            Pin<Box<dyn Future<Output = eyre::Result<()>> + Send>>,
            TestExExHandle,
        )> {
            let (ctx, handle) = test_exex_context(self.chain_spec.clone(), self.port).await?;
            let connection = Connection::open_in_memory()?;
            let unifi = Box::pin(UnifiRollup::new(ctx, connection)?.start());
            Ok((unifi, handle))
        }
    }

    /// Creates a new [`ExExContext`].
    ///
    /// This is a convenience function that does the following:
    /// 1. Sets up an [`ExExContext`] with all dependencies.
    /// 2. Inserts the genesis block of the provided (chain spec)[`ChainSpec`] into the storage.
    /// 3. Creates a channel for receiving events from the Execution Extension.
    /// 4. Creates a channel for sending notifications to the Execution Extension.
    ///
    /// # Warning
    /// The genesis block is not sent to the notifications channel. The caller is responsible for
    /// doing this.
    pub async fn test_exex_context(
        chain_spec: Arc<ChainSpec>,
        port: u16,
    ) -> eyre::Result<(ExExContext<Adapter>, TestExExHandle)> {
        let transaction_pool = testing_pool();
        let evm_config = EthEvmConfig::default();
        let executor = MockExecutorProvider::default();
        let consensus = Arc::new(TestConsensus::default());

        let provider_factory = create_test_provider_factory_with_chain_spec(chain_spec);
        let genesis_hash = init_genesis(provider_factory.clone())?;
        let provider = BlockchainProvider::new(
            provider_factory.clone(),
            Arc::new(NoopBlockchainTree::default()),
        )?;
        let network_config_builder =
            NetworkConfigBuilder::new(SecretKey::new(&mut rand::thread_rng())).discovery_port(port);

        let network_manager =
            NetworkManager::new(network_config_builder.build(provider_factory.clone())).await?;
        dbg!(network_manager.local_addr());
        let network = network_manager.handle().clone();

        let (_, payload_builder) = NoopPayloadBuilderService::<EthEngineTypes>::new();

        let tasks = TaskManager::current();
        let task_executor = tasks.executor();

        let components = NodeAdapter::<FullNodeTypesAdapter<TestNode, _, _>, _> {
            components: Components {
                transaction_pool,
                evm_config,
                executor,
                consensus,
                network,
                payload_builder,
            },
            task_executor,
            provider,
        };

        let genesis = provider_factory
            .block_by_hash(genesis_hash)?
            .ok_or(eyre::eyre!("genesis block not found"))?
            .seal_slow()
            .seal_with_senders()
            .ok_or(eyre::eyre!("failed to recover senders"))?;

        let head = Head {
            number: genesis.number,
            hash: genesis_hash,
            difficulty: genesis.difficulty,
            timestamp: genesis.timestamp,
            total_difficulty: Default::default(),
        };

        let (events_tx, events_rx) = tokio::sync::mpsc::unbounded_channel();
        let (notifications_tx, notifications_rx) = tokio::sync::mpsc::channel(1);

        let ctx = ExExContext {
            head,
            config: NodeConfig::test(),
            reth_config: reth_config::Config::default(),
            events: events_tx,
            notifications: notifications_rx,
            components,
        };

        Ok((
            ctx,
            TestExExHandle {
                genesis,
                provider_factory,
                events_rx,
                notifications_tx,
                tasks,
            },
        ))
    }

    pub fn construct_chain(
        block_num: u64,
        tx_count: u8,
        parent: Option<FixedBytes<32>>,
    ) -> eyre::Result<Chain> {
        let mut rng: ThreadRng = rand::thread_rng();

        // Generate a random block
        let block = random_block(&mut rng, block_num, parent, Some(tx_count), None)
            .seal_with_senders()
            .ok_or_else(|| eyre::eyre!("failed to recover senders"))?;

        let receipts = block
            .body
            .iter()
            .map(|tx| random_receipt(&mut rng, tx, None))
            .collect::<Vec<Receipt>>();

        // Construct a chain
        let chain = Chain::new(
            vec![block.clone()],
            ExecutionOutcome::new(
                BundleState::default(),
                receipts.into(),
                block.number,
                vec![block.requests.clone().unwrap_or_default()],
            ),
            None,
        );
        Ok(chain)
    }

    pub fn deploy_unifi_contracts_tx() -> eyre::Result<()> {
        // UnifiContract::UnifiContractCalls::
        let bytecode = "0x6080604052348015600e575f80fd5b50435f556102f68061001f5f395ff3fe608060405234801561000f575f80fd5b506004361061004a575f3560e01c80630356fe3a1461004e578063be5e78ba14610068578063e172c47814610087578063f4fca1de146100a6575b5f80fd5b6100565f5481565b60405190815260200160405180910390f35b610056610076366004610197565b60026020525f908152604090205481565b610056610095366004610197565b60016020525f908152604090205481565b6100b96100b43660046101f3565b6100bb565b005b82515f908152600260205260408120805490826100d78361029c565b919050559050836020015181146101085760405163215cd2a960e11b81526004810182905260240160405180910390fd5b83515f90815260016020526040902054439003610138576040516311521db560e11b815260040160405180910390fd5b83515f908152600160209081526040918290204390558551828701516060880151845191825292810192909252917ff5bf4c4c5cd6a5cd4ff7cd890e34c27b8c163f59ef0acecd903628a20ddd8569910160405180910390a250505050565b5f602082840312156101a7575f80fd5b5035919050565b5f8083601f8401126101be575f80fd5b50813567ffffffffffffffff8111156101d5575f80fd5b6020830191508360208285010111156101ec575f80fd5b9250929050565b5f805f83850360a0811215610206575f80fd5b6080811215610213575f80fd5b506040516080810181811067ffffffffffffffff8211171561024357634e487b7160e01b5f52604160045260245ffd5b604090815285358252602080870135908301528581013590820152606080860135908201529250608084013567ffffffffffffffff811115610283575f80fd5b61028f868287016101ae565b9497909650939450505050565b5f600182016102b957634e487b7160e01b5f52601160045260245ffd5b506001019056fea2646970667358221220e46dfc264081b565f2cf0d0b4d66b2046f06d04dd8c65d7104a9aad89f515b6764736f6c634300081a0033";
        let tx = TransactionRequest::default().with_deploy_code(bytecode);

        // convert to eip1559 tx
        // Ok(tx.build_typed_tx())

        // Deploy puffer unifi contract via alloy
        // This would involve interacting with the Ethereum network, which is beyond the scope of this example
        Ok(())
    }

    pub fn create_l2_blob(n: usize, m: usize) -> eyre::Result<Vec<u8>> {
        let mut blob = Vec::new();
        for _ in 0..m {
            let block = generate_random_block(n)?;
            blob.extend(block);
        }
        Ok(blob)
    }

    pub fn generate_random_block(n: usize) -> eyre::Result<Vec<u8>> {
        // Generate n random transactions and encode as a block
        // This is a simplified version and would need to be expanded
        let mut block = Vec::new();
        for _ in 0..n {
            let tx = generate_random_transaction()?;
            block.extend(tx);
        }
        Ok(block)
    }

    pub fn generate_random_transaction() -> eyre::Result<Vec<u8>> {
        // Generate a random transaction
        // This is a placeholder and would need to be implemented properly
        Ok(vec![0; 32])
    }

    fn create_l1_block(n: usize, m: usize) -> eyre::Result<Vec<u8>> {
        let blob_tx = create_l2_blob(n, m)?;
        let mut block = Vec::new();
        for _ in 0..n {
            let tx = generate_random_transaction()?;
            block.extend(tx);
        }
        block.extend(blob_tx);
        Ok(block)
    }

    #[tokio::test]
    async fn test_unifi_exex() -> eyre::Result<()> {
        // Initialize a test Execution Extension context with all dependencies
        let (mut unifi, mut handle) = TestUnifiRollup::new(HOLESKY.clone(), 3031).setup().await?;

        // Construct a chain with a single block
        let chain = construct_chain(69, 1, None)?;

        // Send a notification to the Execution Extension that the chain has been committed
        handle
            .send_notification_chain_committed(chain.clone())
            .await?;

        // Check that the Execution Extension did not emit any events until we polled it
        handle.assert_events_empty();

        // Poll the Execution Extension once to process incoming notifications
        unifi.poll_once().await?;

        // Check that the Execution Extension emitted a `FinishedHeight` event with the correct
        handle.assert_event_finished_height(chain.tip().number as u64)?;

        Ok(())
    }
}

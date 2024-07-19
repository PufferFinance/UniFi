use reth::{
    blockchain_tree::noop::NoopBlockchainTree,
    builder::{components::Components, NodeAdapter, NodeConfig},
    network::{config::SecretKey, NetworkConfigBuilder, NetworkManager},
    payload::noop::NoopPayloadBuilderService,
    primitives::{
        Address, Block, Header, Log, Receipt, Transaction, TransactionSigned, TxKind, TxLegacy,
        TxType, U256,
    },
    providers::{
        providers::BlockchainProvider,
        test_utils::create_test_provider_factory_with_chain_spec, BlockReader,
    },
    revm::{db::BundleState, primitives::FixedBytes},
    tasks::TaskManager,
    transaction_pool::test_utils::testing_pool,
};
use rand::rngs::ThreadRng;
use reth_chainspec::{ChainSpec, Head, DEV, HOLESKY};
use reth_consensus::test_utils::TestConsensus;
use reth_db_common::init::init_genesis;
use reth_evm::test_utils::MockExecutorProvider;
use reth_execution_types::{Chain, ExecutionOutcome};
use reth_exex::ExExContext;
use reth_exex_test_utils::{
    test_exex_context_with_chain_spec, Adapter, PollOnce, TestExExHandle, TestNode,
};
use reth_node_api::FullNodeTypesAdapter;
use reth_node_ethereum::{EthEngineTypes, EthEvmConfig};
use reth_testing_utils::generators::{random_block, random_receipt, random_signed_tx};
use std::{pin::pin, sync::Arc};

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
    port: u16
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
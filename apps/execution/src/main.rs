mod exex;
mod db;
mod testing;

use exex::UnifiRollup;
use reth_node_ethereum::EthereumNode;
use rusqlite::Connection;


const DATABASE_PATH: &str = "rollup.db";

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
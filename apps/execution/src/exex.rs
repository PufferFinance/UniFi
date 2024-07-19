use futures::Future;
use reth_exex::{ExExContext, ExExEvent, ExExNotification};
use reth_node_api::FullNodeComponents;
use reth_tracing::tracing::info;

// struct UnifiHandler<Node: FullNodeComponents> {
//     ctx: ExExContext<Node>,
//     db: Database,
// }

/// The initialization logic of the ExEx is just an async function.
///
/// During initialization you can wait for resources you need to be up for the ExEx to function,
/// like a database connection.
pub async fn exex_init<Node: FullNodeComponents>(
    ctx: ExExContext<Node>,
) -> eyre::Result<impl Future<Output = eyre::Result<()>>> {
    Ok(exex(ctx))
}

/// An ExEx is just a future, which means you can implement all of it in an async function!
///
/// This ExEx just prints out whenever either a new chain of blocks being added, or a chain of
/// blocks being re-orged. After processing the chain, emits an [ExExEvent::FinishedHeight] event.
async fn exex<Node: FullNodeComponents>(mut ctx: ExExContext<Node>) -> eyre::Result<()> {
    while let Some(notification) = ctx.notifications.recv().await {
        match &notification {
            ExExNotification::ChainCommitted { new } => {
                info!(committed_chain = ?new.range(), "Received commit");
            }
            ExExNotification::ChainReorged { old, new } => {
                info!(from_chain = ?old.range(), to_chain = ?new.range(), "Received reorg");
            }
            ExExNotification::ChainReverted { old } => {
                info!(reverted_chain = ?old.range(), "Received revert");
            }
        };

        if let Some(committed_chain) = notification.committed_chain() {
            ctx.events
                .send(ExExEvent::FinishedHeight(committed_chain.tip().number))?;
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use rand::rngs::ThreadRng;
    use reth_chainspec::{HOLESKY};
    use reth_exex_test_utils::{
        PollOnce,
    };
    use std::{pin::pin};

    use crate::testing::{construct_chain, test_exex_context};

    #[tokio::test]
    async fn test_exex() -> eyre::Result<()> {
        // Initialize a test Execution Extension context with all dependencies
        let port = 3031;
        let (ctx, mut handle) = test_exex_context(HOLESKY.clone(), port).await?;

        // Construct a chain with a single block
        let mut chain = construct_chain(69, 1, None)?;
        // let mut chain = construct_chain(ctx.head.number, 1, None)?;

        // Send a notification to the Execution Extension that the chain has been committed
        handle
            .send_notification_chain_committed(chain.clone())
            .await?;

        // Construct a second chain with a single block and append
        // let chain2 = construct_chain(ctx.head.number + 1, 1, Some(chain.tip().hash()))?;
        // assert!(chain.append_chain(chain2.clone()).is_ok());

        // // Send a notification to the Execution Extension that the chain has been committed
        // handle
        //     .send_notification_chain_committed(chain.clone())
        //     .await?;

        // Initialize the Execution Extension
        let mut exex = pin!(super::exex_init(ctx).await?);

        // Check that the Execution Extension did not emit any events until we polled it
        handle.assert_events_empty();

        // Poll the Execution Extension once to process incoming notifications
        exex.poll_once().await?;

        // Check that the Execution Extension emitted a `FinishedHeight` event with the correct
        handle.assert_event_finished_height(chain.tip().block.number as u64)?;

        Ok(())
    }
}
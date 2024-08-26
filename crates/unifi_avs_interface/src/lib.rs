use alloy::{sol, sol_types, primitives::Address};
use UniFiAVSManager::OperatorDataExtended;
use eyre::Result;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

impl UniFiAVSManager {
    pub async fn get_operator(&self, operator: Address) -> Result<OperatorDataExtended, alloy::rpc::Error> {
        self.get_operator(operator).call().await
    }
}
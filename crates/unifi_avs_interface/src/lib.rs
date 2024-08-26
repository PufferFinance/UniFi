use alloy::{sol, sol_types, primitives::Address};
use UniFiAVSManager::OperatorDataExtended;
use eyre::Result;
use alloy_rpc_client::RpcClient;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

impl UniFiAVSManager {
    pub async fn get_operator(&self, operator: Address) -> Result<OperatorDataExtended, alloy::rpc::Error> {
        self.get_operator(operator).call().await
    }

    pub fn new_test(address: Address, client: RpcClient) -> Self {
        Self::new(address).with_client(client)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_rpc_client::RpcClientBuilder;
    use std::str::FromStr;

    pub async fn setup_test_client() -> (UniFiAVSManager, Address) {
        let rpc_url = "http://localhost:8545"; // Assuming local Anvil instance
        let client = RpcClientBuilder::default().build(rpc_url).unwrap();
        
        // Replace with your deployed contract address
        let contract_address = Address::from_str("0x5FbDB2315678afecb367f032d93F642f64180aa3").unwrap();
        
        let unifi_avs_manager = UniFiAVSManager::new_test(contract_address, client);
        
        (unifi_avs_manager, contract_address)
    }
}

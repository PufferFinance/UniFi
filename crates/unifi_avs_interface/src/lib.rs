use alloy::{sol, sol_types, primitives::Address};
use UniFiAVSManager::OperatorDataExtended;
use eyre::Result;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

impl UniFiAVSManager {
    pub async fn get_operator(&self, operator: Address) -> Result<OperatorDataExtended> {
        self.get_operator(operator).call().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{
        providers::{Provider, Http},
        rpc::client::RpcClient,
    };
    use std::str::FromStr;

    #[tokio::test]
    async fn test_get_operator() -> Result<()> {
        // Connect to the existing Anvil instance
        let rpc_url = "http://127.0.0.1:8545";
        let provider = Provider::<Http>::try_from(rpc_url)?;

        // Replace with your deployed contract address
        let contract_address = Address::from_str("0x5FbDB2315678afecb367f032d93F642f64180aa3")?;
        let unifi_avs_manager = UniFiAVSManager::new(contract_address).with_provider(provider);

        // Replace with a valid operator address that you've registered in your local deployment
        let operator_address = Address::from_str("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")?;

        match unifi_avs_manager.get_operator(operator_address).await {
            Ok(operator_data) => {
                println!("Operator data: {:?}", operator_data);
                // Add assertions here to check the returned data
                assert!(operator_data.is_registered);
                // Add more assertions based on your expected data
            }
            Err(e) => {
                panic!("Failed to get operator data: {:?}", e);
            }
        }

        Ok(())
    }
}

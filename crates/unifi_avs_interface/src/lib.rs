use alloy::{sol, primitives::Address, providers::Provider};
use eyre::Result;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

pub struct UniFiAVSManagerWrapper(UniFiAVSManager);

impl UniFiAVSManagerWrapper {
    pub fn new(address: Address, provider: impl Into<Provider>) -> Self {
        Self(UniFiAVSManager::new(address, provider.into()))
    }

    pub async fn get_operator(&self, operator: Address) -> Result<UniFiAVSManager::OperatorDataExtended> {
        self.0.get_operator(operator).call().await
    }

    pub async fn register_operator(&self, operator_signature: UniFiAVSManager::SignatureWithSaltAndExpiry) -> Result<()> {
        self.0.register_operator(operator_signature).send().await?;
        Ok(())
    }

    pub async fn register_validators(&self, pod_owner: Address, bls_pub_key_hashes: Vec<[u8; 32]>) -> Result<()> {
        self.0.register_validators(pod_owner, bls_pub_key_hashes).send().await?;
        Ok(())
    }

    pub async fn deregister_validators(&self, bls_pub_key_hashes: Vec<[u8; 32]>) -> Result<()> {
        self.0.deregister_validators(bls_pub_key_hashes).send().await?;
        Ok(())
    }

    pub async fn start_deregister_operator(&self) -> Result<()> {
        self.0.start_deregister_operator().send().await?;
        Ok(())
    }

    pub async fn finish_deregister_operator(&self) -> Result<()> {
        self.0.finish_deregister_operator().send().await?;
        Ok(())
    }

    pub async fn get_validator(&self, bls_pub_key_hash: [u8; 32]) -> Result<UniFiAVSManager::ValidatorDataExtended> {
        self.0.get_validator(bls_pub_key_hash).call().await
    }

    pub async fn get_validator_by_index(&self, validator_index: u64) -> Result<UniFiAVSManager::ValidatorDataExtended> {
        self.0.get_validator(validator_index).call().await
    }

    pub async fn get_validators(&self, bls_pub_key_hashes: Vec<[u8; 32]>) -> Result<Vec<UniFiAVSManager::ValidatorDataExtended>> {
        self.0.get_validators(bls_pub_key_hashes).call().await
    }

    pub async fn set_operator_commitment(&self, new_commitment: UniFiAVSManager::OperatorCommitment) -> Result<()> {
        self.0.set_operator_commitment(new_commitment).send().await?;
        Ok(())
    }

    pub async fn update_operator_commitment(&self) -> Result<()> {
        self.0.update_operator_commitment().send().await?;
        Ok(())
    }

    pub async fn is_validator_in_chain_id(&self, bls_pub_key_hash: [u8; 32], chain_id: u64) -> Result<bool> {
        self.0.is_validator_in_chain_id(bls_pub_key_hash, chain_id).call().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::providers::{Provider, Http};
    use std::str::FromStr;

    #[tokio::test]
    async fn test_get_operator() -> Result<()> {
        // Connect to the existing Anvil instance
        let rpc_url = "http://127.0.0.1:8545";
        let provider = Provider::<Http>::try_from(rpc_url)?;

        // Replace with your deployed contract address
        let contract_address = Address::from_str("0x5FbDB2315678afecb367f032d93F642f64180aa3")?;
        let unifi_avs_manager = UniFiAVSManagerWrapper::new(contract_address, provider);

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

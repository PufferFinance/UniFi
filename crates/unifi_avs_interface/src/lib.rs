use alloy::{
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder},
    sol,
};
use eyre::Result;
use std::str::FromStr;
use thiserror::Error;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

#[derive(Error, Debug)]
pub enum UniFiAVSManagerError {
    #[error("Registration expired")]
    RegistrationExpired,
    #[error("Invalid operator salt")]
    InvalidOperatorSalt,
    #[error("Signature expired")]
    SignatureExpired,
    #[error("Operator has validators")]
    OperatorHasValidators,
    #[error("Not operator")]
    NotOperator,
    #[error("No EigenPod")]
    NoEigenPod,
    #[error("Deregistration delay not elapsed")]
    DeregistrationDelayNotElapsed,
    #[error("Deregistration already started")]
    DeregistrationAlreadyStarted,
    #[error("Deregistration not started")]
    DeregistrationNotStarted,
    #[error("Not delegated to operator")]
    NotDelegatedToOperator,
    #[error("Validator not active")]
    ValidatorNotActive,
    #[error("Operator already exists")]
    OperatorAlreadyExists,
    #[error("Operator not registered")]
    OperatorNotRegistered,
    #[error("Operator already registered")]
    OperatorAlreadyRegistered,
    #[error("Not validator operator")]
    NotValidatorOperator,
    #[error("Validator already registered")]
    ValidatorAlreadyRegistered,
    #[error("Delegate key not set")]
    DelegateKeyNotSet,
    #[error("Invalid operator")]
    InvalidOperator,
    #[error("Not pod owner")]
    NotPodOwner,
    #[error("Validator not found")]
    ValidatorNotFound,
    #[error("Unauthorized")]
    Unauthorized,
    #[error("Invalid address")]
    InvalidAddress,
    #[error("Invalid amount")]
    InvalidAmount,
    #[error("Delegate key change not ready")]
    DelegateKeyChangeNotReady,
    #[error("Commitment change not ready")]
    CommitmentChangeNotReady,
}

pub struct UniFiAVSManagerWrapper {
    address: Address,
    rpc_url: String,
}

impl UniFiAVSManagerWrapper {
    pub fn new(address: Address, rpc_url: String) -> Self {
        Self { address, rpc_url }
    }

    async fn get_provider(&self) -> Result<UniFiAVSManager::UniFiAVSManagerCalls> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        Ok(UniFiAVSManager::new(self.address, provider.into()))
    }

    pub async fn get_operator(&self, operator: Address) -> Result<UniFiAVSManager::OperatorDataExtended> {
        let provider = self.get_provider().await?;
        provider.get_operator(operator).call().await
    }

    pub async fn get_validator(&self, bls_pub_key_hash: [u8; 32]) -> Result<UniFiAVSManager::ValidatorDataExtended> {
        let provider = self.get_provider().await?;
        provider.get_validator(bls_pub_key_hash).call().await
    }

    pub async fn get_validator_by_index(&self, validator_index: U256) -> Result<UniFiAVSManager::ValidatorDataExtended> {
        let provider = self.get_provider().await?;
        provider.get_validator(validator_index).call().await
    }

    pub async fn get_validators(&self, bls_pub_key_hashes: Vec<[u8; 32]>) -> Result<Vec<UniFiAVSManager::ValidatorDataExtended>> {
        let provider = self.get_provider().await?;
        provider.get_validators(bls_pub_key_hashes).call().await
    }

    pub async fn set_operator_commitment(&self, new_commitment: UniFiAVSManager::OperatorCommitment) -> Result<()> {
        let provider = self.get_provider().await?;
        provider.set_operator_commitment(new_commitment).send().await?;
        Ok(())
    }

    pub async fn update_operator_commitment(&self) -> Result<()> {
        let provider = self.get_provider().await?;
        provider.update_operator_commitment().send().await?;
        Ok(())
    }

    pub async fn is_validator_in_chain_id(&self, bls_pub_key_hash: [u8; 32], chain_id: U256) -> Result<bool> {
        let provider = self.get_provider().await?;
        provider.is_validator_in_chain_id(bls_pub_key_hash, chain_id).call().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_operator() -> Result<()> {
        // Replace with your deployed contract address
        let contract_address = Address::from_str("0x5FbDB2315678afecb367f032d93F642f64180aa3")?;
        let rpc_url = "http://127.0.0.1:8545".to_string();
        let unifi_avs_manager = UniFiAVSManagerWrapper::new(contract_address, rpc_url);

        // Replace with a valid operator address that you've registered in your local deployment
        let operator_address = Address::from_str("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")?;

        match unifi_avs_manager.get_operator(operator_address).await {
            Ok(operator_data) => {
                println!("Operator data: {:?}", operator_data.commitmentValidAfter);
                // Add assertions here to check the returned data
                assert!(operator_data.isRegistered);
                // Add more assertions based on your expected data
            }
            Err(e) => {
                panic!("Failed to get operator data: {:?}", e);
            }
        }

        Ok(())
    }
}

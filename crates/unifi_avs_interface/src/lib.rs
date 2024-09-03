use alloy::{
    primitives::{address, utils::keccak256, Address, FixedBytes, U256},
    providers::{Provider, ProviderBuilder},
    sol,
};
use eyre::Result;
use thiserror::Error;
use UniFiAVSManager::isValidatorInChainIdReturn;

sol! {
    #[sol(rpc)]
    #[derive(Debug)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
}

/// Errors that can occur when interacting with the UniFiAVSManager contract
#[derive(Error, Debug)]
pub enum UniFiAVSManagerError {
    #[error("RPC error: {0}")]
    RPCError(String),
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

/// Wrapper for interacting with the UniFiAVSManager contract
pub struct UniFiAVSManagerWrapper {
    address: Address,
    rpc_url: String,
}

impl UniFiAVSManagerWrapper {
    /// Creates a new instance of UniFiAVSManagerWrapper
    ///
    /// # Arguments
    /// * `address` - The address of the UniFiAVSManager contract
    /// * `rpc_url` - The URL of the RPC endpoint
    pub fn new(address: Address, rpc_url: String) -> Self {
        Self { address, rpc_url }
    }

    /// Retrieves information about a specific operator
    ///
    /// # Arguments
    /// * `operator` - The address of the operator
    ///
    /// # Returns
    /// Information about the operator or an error
    pub async fn get_operator(
        &self,
        operator: Address,
    ) -> Result<UniFiAVSManager::getOperatorReturn> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        let contract = UniFiAVSManager::new(self.address, provider);
        contract
            .getOperator(operator)
            .call()
            .await
            .map_err(|e| UniFiAVSManagerError::RPCError(e.to_string()).into())
    }

    /// Retrieves validator information by the hash of its BLS public key
    ///
    /// # Arguments
    /// * `bls_pub_key_hash` - The hash of the validator's BLS public key
    ///
    /// # Returns
    /// Validator information or an error
    pub async fn get_validator_by_hash(
        &self,
        bls_pub_key_hash: [u8; 32],
    ) -> Result<UniFiAVSManager::getValidator_1Return> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        let contract = UniFiAVSManager::new(self.address, provider);
        contract
            .getValidator_1(bls_pub_key_hash.into())
            .call()
            .await
            .map_err(|e| UniFiAVSManagerError::RPCError(e.to_string()).into())
    }

    /// Retrieves validator information by its BLS public key
    ///
    /// # Arguments
    /// * `bls_pub_key` - The validator's BLS public key
    ///
    /// # Returns
    /// Validator information or an error
    pub async fn get_validator(
        &self,
        bls_pub_key: [u8; 48],
    ) -> Result<UniFiAVSManager::getValidator_1Return> {
        let bls_pub_key_hash = keccak256(bls_pub_key);
        self.get_validator_by_hash(bls_pub_key_hash.into()).await
    }

    /// Retrieves validator information by its index
    ///
    /// # Arguments
    /// * `validator_index` - The index of the validator
    ///
    /// # Returns
    /// Validator information or an error
    pub async fn get_validator_by_index(
        &self,
        validator_index: u64,
    ) -> Result<UniFiAVSManager::getValidator_0Return> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        let contract = UniFiAVSManager::new(self.address, provider);
        contract
            .getValidator_0(U256::from(validator_index))
            .call()
            .await
            .map_err(|e| UniFiAVSManagerError::RPCError(e.to_string()).into())
    }

    /// Retrieves information for multiple validators by their BLS public key hashes
    ///
    /// # Arguments
    /// * `bls_pub_key_hashes` - A vector of BLS public key hashes
    ///
    /// # Returns
    /// Information for multiple validators or an error
    pub async fn get_validators_by_hashes(
        &self,
        bls_pub_key_hashes: Vec<[u8; 32]>,
    ) -> Result<UniFiAVSManager::getValidatorsReturn> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        let contract = UniFiAVSManager::new(self.address, provider);
        contract
            .getValidators(
                bls_pub_key_hashes
                    .into_iter()
                    .map(FixedBytes::from)
                    .collect(),
            )
            .call()
            .await
            .map_err(|e| UniFiAVSManagerError::RPCError(e.to_string()).into())
    }

    /// Retrieves information for multiple validators by their BLS public keys
    ///
    /// # Arguments
    /// * `bls_pub_keys` - A vector of BLS public keys
    ///
    /// # Returns
    /// Information for multiple validators or an error
    pub async fn get_validators(
        &self,
        bls_pub_keys: Vec<[u8; 48]>,
    ) -> Result<UniFiAVSManager::getValidatorsReturn> {
        let bls_pub_key_hashes: Vec<[u8; 32]> = bls_pub_keys
            .into_iter()
            .map(|key| keccak256(key).into())
            .collect();
        self.get_validators_by_hashes(bls_pub_key_hashes).await
    }

    /// Checks if a validator is in a specific chain ID by its BLS public key hash
    ///
    /// # Arguments
    /// * `bls_pub_key_hash` - The hash of the validator's BLS public key
    /// * `chain_id` - The chain ID to check
    ///
    /// # Returns
    /// A boolean indicating if the validator is in the specified chain ID, or an error
    pub async fn is_validator_hash_in_chain_id(
        &self,
        bls_pub_key_hash: [u8; 32],
        chain_id: u64,
    ) -> Result<bool> {
        let provider = ProviderBuilder::new().on_http(self.rpc_url.parse()?);
        let contract = UniFiAVSManager::new(self.address, provider);
        let resp = contract
            .isValidatorInChainId(bls_pub_key_hash.into(), U256::from(chain_id))
            .call()
            .await?;
        Ok(resp._0)
    }

    /// Checks if a validator is in a specific chain ID by its BLS public key
    ///
    /// # Arguments
    /// * `bls_pub_key` - The validator's BLS public key
    /// * `chain_id` - The chain ID to check
    ///
    /// # Returns
    /// A boolean indicating if the validator is in the specified chain ID, or an error
    pub async fn is_validator_in_chain_id(
        &self,
        bls_pub_key: [u8; 48],
        chain_id: u64,
    ) -> Result<bool> {
        let bls_pub_key_hash = keccak256(bls_pub_key);
        self.is_validator_hash_in_chain_id(bls_pub_key_hash.into(), chain_id)
            .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{hex, primitives::bytes};

    fn setup() -> UniFiAVSManagerWrapper {
        let contract_address = address!("5CcEa336064524a3D7d636e33BFd53f2917F27A0");
        let rpc_url = std::env::var("HELDER_RPC").expect("HELDER_RPC environment variable not set");
        UniFiAVSManagerWrapper::new(contract_address, rpc_url)
    }

    #[tokio::test]
    async fn test_get_operator() -> Result<()> {
        let unifi_avs_manager = setup();
        let operator = address!("A85Fdcb45aaFF3C310a47FE309D4a35FAfbdc0ad");

        let operator_data = unifi_avs_manager.get_operator(operator).await?;
        assert!(operator_data._0.isRegistered);
        // assert_eq!(operator_data._0.validatorCount, 2);
        assert_eq!(operator_data._0.startDeregisterOperatorBlock, 0);
        assert_eq!(operator_data._0.commitment.delegateKey, bytes!("DEADBEEF"));
        dbg!(operator_data._0.commitment.delegateKey.len());
        assert_eq!(operator_data._0.commitment.chainIDBitMap, U256::from(5));
        Ok(())
    }

    #[tokio::test]
    async fn test_get_validator() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey = hex!("b3af9fbabd939d07121818c79aca09f7abd9fb636768a86388bdcfb694a55f670325c50d1776e8f75aaf94bfffe69131");

        let validator_data = unifi_avs_manager.get_validator(validator_pubkey).await?;
        assert_eq!(validator_data._0.validatorIndex, 1300);

        let validator_pubkey = hex!("80bb511562da9b3cb9c9f3721213f312d872bfded3601a3fe2c6ad157e3ac8a4748752d7eee281b630e1447c62813f16");

        let validator_data = unifi_avs_manager.get_validator(validator_pubkey).await?;
        assert_eq!(validator_data._0.validatorIndex, 1301);
        Ok(())
    }

    #[tokio::test]
    async fn test_get_validator_by_hash() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey = hex!("b3af9fbabd939d07121818c79aca09f7abd9fb636768a86388bdcfb694a55f670325c50d1776e8f75aaf94bfffe69131");
        let validator_hash: [u8; 32] = keccak256(validator_pubkey).into();

        let validator_data = unifi_avs_manager
            .get_validator_by_hash(validator_hash)
            .await?;
        assert_eq!(validator_data._0.validatorIndex, 1300);
        Ok(())
    }

    #[tokio::test]
    async fn test_get_validator_by_index() -> Result<()> {
        let unifi_avs_manager = setup();

        let validator_data = unifi_avs_manager.get_validator_by_index(1300).await?;
        assert_eq!(validator_data._0.validatorIndex, 1300);
        assert_eq!(
            validator_data._0.operator,
            address!("A85Fdcb45aaFF3C310a47FE309D4a35FAfbdc0ad")
        );
        assert_eq!(validator_data._0.status, 1); // 1 is ACTIVE status
        assert_eq!(validator_data._0.delegateKey, bytes!("DEADBEEF"));
        assert_eq!(validator_data._0.chainIDBitMap, U256::from(5));
        assert!(validator_data._0.backedByStake);
        assert!(validator_data._0.registered);
        Ok(())
    }

    #[tokio::test]
    async fn test_get_validators() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey0 = hex!("b3af9fbabd939d07121818c79aca09f7abd9fb636768a86388bdcfb694a55f670325c50d1776e8f75aaf94bfffe69131");
        let validator_pubkey1 = hex!("80bb511562da9b3cb9c9f3721213f312d872bfded3601a3fe2c6ad157e3ac8a4748752d7eee281b630e1447c62813f16");

        let validators_data = unifi_avs_manager
            .get_validators(vec![validator_pubkey0, validator_pubkey1])
            .await?;
        assert_eq!(validators_data._0.len(), 2);
        assert_eq!(validators_data._0[0].validatorIndex, 1300);
        assert_eq!(validators_data._0[1].validatorIndex, 1301);
        Ok(())
    }

    #[tokio::test]
    async fn test_get_validators_by_hashes() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey0 = hex!("b3af9fbabd939d07121818c79aca09f7abd9fb636768a86388bdcfb694a55f670325c50d1776e8f75aaf94bfffe69131");
        let validator_pubkey1 = hex!("80bb511562da9b3cb9c9f3721213f312d872bfded3601a3fe2c6ad157e3ac8a4748752d7eee281b630e1447c62813f16");
        let validator_hash0: [u8; 32] = keccak256(validator_pubkey0).into();
        let validator_hash1: [u8; 32] = keccak256(validator_pubkey1).into();

        let validators_data = unifi_avs_manager
            .get_validators_by_hashes(vec![validator_hash0, validator_hash1])
            .await?;
        assert_eq!(validators_data._0.len(), 2);
        assert_eq!(validators_data._0[0].validatorIndex, 1300);
        assert_eq!(validators_data._0[1].validatorIndex, 1301);
        Ok(())
    }

    #[tokio::test]
    async fn test_is_validator_in_chain_id() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey = hex!("80bb511562da9b3cb9c9f3721213f312d872bfded3601a3fe2c6ad157e3ac8a4748752d7eee281b630e1447c62813f16");

        // index 1 = 0x11111111
        let is_in_chain = unifi_avs_manager
            .is_validator_in_chain_id(validator_pubkey, 0x11111111)
            .await?;
        assert!(is_in_chain);

        // index 3 = 0x22222222
        let is_in_chain = unifi_avs_manager
            .is_validator_in_chain_id(validator_pubkey, 0x22222222)
            .await?;
        assert!(is_in_chain);

        // not set
        let is_in_chain = unifi_avs_manager
            .is_validator_in_chain_id(validator_pubkey, 0x33333333)
            .await?;
        assert!(!is_in_chain);
        Ok(())
    }

    #[tokio::test]
    async fn test_is_validator_hash_in_chain_id() -> Result<()> {
        let unifi_avs_manager = setup();
        let validator_pubkey = hex!("80bb511562da9b3cb9c9f3721213f312d872bfded3601a3fe2c6ad157e3ac8a4748752d7eee281b630e1447c62813f16");
        let validator_hash: [u8; 32] = keccak256(validator_pubkey).into();
        // index 1 = 0x11111111
        let is_in_chain = unifi_avs_manager
            .is_validator_hash_in_chain_id(validator_hash, 0x11111111)
            .await?;
        assert!(is_in_chain);

        // index 3 = 0x22222222
        let is_in_chain = unifi_avs_manager
            .is_validator_hash_in_chain_id(validator_hash, 0x22222222)
            .await?;
        assert!(is_in_chain);

        // not set
        let is_in_chain = unifi_avs_manager
            .is_validator_hash_in_chain_id(validator_hash, 0x33333333)
            .await?;
        assert!(!is_in_chain);
        Ok(())
    }
}

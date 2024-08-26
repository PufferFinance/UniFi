use alloy::{sol, sol_types, primitives::Address};
use UniFiAVSManager::OperatorDataExtended;
use eyre::Result;
// use alloy::rpc_client::RpcClient;

sol!(
    #[sol(rpc)]
    UniFiAVSManager,
    "../../l1-contracts/out/UniFiAVSManager.sol/UniFiAVSManager.json"
);

// struct UniFiAVSManagerClient;

// impl UniFiAVSManager {
//     pub async fn get_operator(&self, operator: Address) -> Result<OperatorDataExtended> {
//         self.get_operator(operator).call().await
//     }
// }

#[cfg(test)]
mod tests {
    use alloy::{primitives::Address, transports::http::reqwest};
use std::str::FromStr;

use alloy::{
    network::EthereumWallet, primitives::U256, providers::ProviderBuilder,
    signers::local::PrivateKeySigner, sol,
};

use alloy_node_bindings::Anvil;
use eyre::Result;

#[tokio::test]
async fn test_get_operator() -> eyre::Result<()>{
    // let anvil = Anvil::new().try_spawn()?;

    // Set up signer from the first default Anvil account (Alice).
    // let signer: PrivateKeySigner = anvil.keys()[0].clone().into();
    let wallet = EthereumWallet::from(signer);

    // Create a provider with the wallet
    // let rpc_url = anvil.endpoint().parse()?;
    let rpc_url: reqwest::Url = reqwest::Url::from("http://localhost:8545");
    let provider =
        ProviderBuilder::new().with_recommended_fillers().wallet(wallet).on_http(rpc_url);

    println!("Anvil running at `{}`", anvil.endpoint());

    // Replace with a valid operator address that you've registered in your local deployment
    let operator_address = Address::from_str("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266").unwrap();
    Ok(())

    // let unifi_avs_manager = sol::UniFiAVSManager::deployed(&provider).await.unwrap();

    // match unifi_avs_manager.get_operator(operator_address).await {
    //     Ok(operator_data) => {
    //         println!("Operator data: {:?}", operator_data);
    //         // Add assertions here to check the returned data
    //         assert!(operator_data.is_registered);
    //         // Add more assertions based on your expected data
    //     }
    //     Err(e) => {
    //         panic!("Failed to get operator data: {:?}", e);
    //     }
    // }
}


}
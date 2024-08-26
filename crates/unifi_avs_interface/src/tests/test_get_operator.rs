use crate::tests::setup_test_client;
use alloy::primitives::Address;
use std::str::FromStr;

#[tokio::test]
async fn test_get_operator() {
    let (unifi_avs_manager, _) = setup_test_client().await;

    // Replace with a valid operator address that you've registered in your local deployment
    let operator_address = Address::from_str("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266").unwrap();

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
}

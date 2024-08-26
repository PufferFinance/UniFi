use alloy_sol_macro::sol;
use alloy_primitives::U256;

sol! {
    interface IUniFiAVSManager {
        function registerOperator(address operator, bytes calldata publicKey, string calldata metadata) external;
        function deregisterOperator(address operator) external;
        function updateOperatorMetadata(address operator, string calldata metadata) external;
        function getOperatorStatus(address operator) external view returns (bool);
        function getOperatorPublicKey(address operator) external view returns (bytes memory);
        function getOperatorMetadata(address operator) external view returns (string memory);
    }
}

pub struct UniFiAVSManager {
    address: [u8; 20],
}

impl UniFiAVSManager {
    pub fn new(address: [u8; 20]) -> Self {
        Self { address }
    }

    // Add methods to interact with the contract here
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

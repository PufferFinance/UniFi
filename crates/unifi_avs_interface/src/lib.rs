use alloy::{sol, sol_types};
use alloy_primitives::Address;

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

// impl OperatorCommitment {
//     const PACKED_ENCODED_SIZE: Option<usize> = None;
// }

// impl OperatorData {
//     const PACKED_ENCODED_SIZE: Option<usize> = None;
// }

// impl ValidatorData {
//     const PACKED_ENCODED_SIZE: Option<usize> = None;
// }

// impl OperatorDataExtended {
//     const PACKED_ENCODED_SIZE: Option<usize> = None;
// }

// impl ValidatorDataExtended {
//     const PACKED_ENCODED_SIZE: Option<usize> = None;
// }

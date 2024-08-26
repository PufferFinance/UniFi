use alloy_sol_macro::sol;
use alloy_primitives::*;

sol! {
    interface IUniFiAVSManager {
        struct OperatorData {
            uint256 operatorId;
            address operatorAddress;
            uint256 stakedAmount;
            bool isActive;
        }

        struct ValidatorData {
            bytes pubkey;
            bytes32 withdrawalCredentials;
            uint256 operatorId;
            bool isActive;
        }

        function registerOperator(address operatorAddress, uint256 stakedAmount) external returns (uint256);
        function deregisterOperator(uint256 operatorId) external;
        function registerValidator(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external;
        function deregisterValidator(bytes calldata pubkey) external;
        function getOperator(uint256 operatorId) external view returns (OperatorData memory);
        function getValidator(bytes calldata pubkey) external view returns (ValidatorData memory);
        function isOperatorActive(uint256 operatorId) external view returns (bool);
        function isValidatorActive(bytes calldata pubkey) external view returns (bool);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_compiles() {
        // This test just ensures that the sol! macro compiles correctly
    }
}

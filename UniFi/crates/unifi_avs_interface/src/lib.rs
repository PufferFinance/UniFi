use alloy_sol_types::sol;

sol! {
    interface IUniFiAVSManager {
        struct OperatorData {
            uint256 operatorId;
            address operatorAddress;
            uint256 stakedAmount;
            uint256 lastUpdateTimestamp;
        }

        struct ValidatorData {
            Vec<u8> pubkey;
            bytes32 withdrawalCredentials;
            uint256 operatorId;
            bool active;
        }

        function registerValidator(Vec<u8> calldata pubkey, Vec<u8> calldata signature, bytes32 depositDataRoot) external;
        function deregisterValidator(Vec<u8> calldata pubkey) external;
        function getValidator(Vec<u8> calldata pubkey) external view returns (ValidatorData memory);
        function isValidatorActive(Vec<u8> calldata pubkey) external view returns (bool);
    }
}

impl OperatorData {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

impl ValidatorData {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

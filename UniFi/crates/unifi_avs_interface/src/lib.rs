use alloy_sol_types::sol;

sol! {
    interface IUniFiAVSManager {
        struct OperatorCommitment {
            Vec<u8> delegateKey;
            uint256 chainIDBitMap;
        }

        struct OperatorData {
            uint128 validatorCount;
            OperatorCommitment commitment;
            OperatorCommitment pendingCommitment;
            uint128 startDeregisterOperatorBlock;
            uint128 commitmentValidAfter;
        }

        struct ValidatorData {
            address eigenPod;
            uint256 index;
            address operator;
            uint64 registeredUntil;
        }

        struct OperatorDataExtended {
            uint128 validatorCount;
            OperatorCommitment commitment;
            OperatorCommitment pendingCommitment;
            uint128 startDeregisterOperatorBlock;
            bool isRegistered;
            uint128 commitmentValidAfter;
        }

        struct ValidatorDataExtended {
            address operator;
            address eigenPod;
            uint256 validatorIndex;
            uint8 status;
            Vec<u8> delegateKey;
            uint256 chainIDBitMap;
            bool backedByStake;
            bool registered;
        }

        function getOperator(address operator) external view returns (OperatorDataExtended memory);
        function getValidator(bytes32 blsPubKeyHash) external view returns (ValidatorDataExtended memory);
        function getValidator(uint256 validatorIndex) external view returns (ValidatorDataExtended memory);
        function getValidators(bytes32[] calldata blsPubKeyHashes) external view returns (ValidatorDataExtended[] memory);
        function getDeregistrationDelay() external view returns (uint64);
        function bitmapToChainIDs(uint256 bitmap) public view returns (uint256[] memory);
        function getChainID(uint8 index) external view returns (uint256);
        function getBitmapIndex(uint256 chainID) external view returns (uint8);
        function isValidatorInChainId(bytes32 blsPubKeyHash, uint256 chainId) external view returns (bool);
    }
}

impl OperatorCommitment {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

impl OperatorData {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

impl ValidatorData {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

impl OperatorDataExtended {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

impl ValidatorDataExtended {
    const PACKED_ENCODED_SIZE: Option<usize> = None;
}

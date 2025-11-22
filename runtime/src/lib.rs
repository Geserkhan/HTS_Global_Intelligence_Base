#![cfg_attr(not(feature = "std"), no_std)]
#![recursion_limit = "256"]

use sp_std::prelude::*;
use sp_core::{crypto::KeyTypeId, OpaqueMetadata};
use sp_runtime::{
    create_runtime_str, generic, impl_opaque_keys,
    traits::{AccountIdLookup, BlakeTwo256, Block as BlockT, IdentifyAccount, NumberFor, Verify},
    transaction_validity::{TransactionSource, TransactionValidity},
    ApplyExtrinsicResult, MultiSignature,
};
use sp_api::impl_runtime_apis;
pub use frame_support::{
    construct_runtime, parameter_types,
    traits::{ConstU128, ConstU16, ConstU32, ConstU64, ConstU8, KeyOwnerProofSystem},
    weights::{IdentityFee, Weight},
};
pub use frame_system::Call as SystemCall;
pub use pallet_timestamp::Call as TimestampCall;
use sp_version::RuntimeVersion;

pub type Signature = MultiSignature;
pub type AccountId = <<Signature as Verify>::Signer as IdentifyAccount>::AccountId;
pub type Balance = u128;
pub type Index = u32;
pub type BlockNumber = u32;
pub type Hash = sp_core::H256;

pub const VERSION: RuntimeVersion = RuntimeVersion {
    spec_name: create_runtime_str!("afe-protocol"),
    impl_name: create_runtime_str!("afe-protocol"),
    authoring_version: 1,
    spec_version: 1,
    impl_version: 1,
    apis: RUNTIME_API_VERSIONS,
    transaction_version: 1,
    state_version: 1,
};

parameter_types! {
    pub const BlockHashCount: BlockNumber = 2400;
    pub const Version: RuntimeVersion = VERSION;
}

// 4대 Pallet 통합
construct_runtime!(
    pub enum Runtime {
        System: frame_system,
        Timestamp: pallet_timestamp,

        // AFE Protocol 4대 핵심 Pallet
        // 🧠 Brain: 리스크 평가 및 Circuit Breaker
        RiskValuation: pallet_risk_valuation,

        // 👁️ Eyes: 가격 피드 및 거버넌스
        OracleGovernance: pallet_oracle_governance,

        // 🛡️ Shield: 영지식 증명 검증
        ZkVerification: pallet_zk_verification,

        // ❤️ Heart: 스테이블코인 대출
        StablecoinLending: pallet_stablecoin_lending,
    }
);

// System Config
impl frame_system::Config for Runtime {
    type BaseCallFilter = frame_support::traits::Everything;
    type BlockWeights = ();
    type BlockLength = ();
    type DbWeight = ();
    type RuntimeOrigin = RuntimeOrigin;
    type RuntimeCall = RuntimeCall;
    type Nonce = Index;
    type Hash = Hash;
    type Hashing = BlakeTwo256;
    type AccountId = AccountId;
    type Lookup = AccountIdLookup<AccountId, ()>;
    type Block = Block;
    type RuntimeEvent = RuntimeEvent;
    type BlockHashCount = BlockHashCount;
    type Version = Version;
    type PalletInfo = PalletInfo;
    type AccountData = ();
    type OnNewAccount = ();
    type OnKilledAccount = ();
    type SystemWeightInfo = ();
    type SS58Prefix = ConstU16<42>;
    type OnSetCode = ();
    type MaxConsumers = ConstU32<16>;
}

// Timestamp Config
impl pallet_timestamp::Config for Runtime {
    type Moment = u64;
    type OnTimestampSet = ();
    type MinimumPeriod = ConstU64<5000>;
    type WeightInfo = ();
}

// 🧠 Brain (Risk Valuation) Config
impl pallet_risk_valuation::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type WeightInfo = ();
}

// 👁️ Eyes (Oracle Governance) Config
impl pallet_oracle_governance::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type WeightInfo = ();
}

// 🛡️ Shield (ZK Verification) Config
impl pallet_zk_verification::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type WeightInfo = ();
}

// ❤️ Heart (Stablecoin Lending) Config
impl pallet_stablecoin_lending::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type WeightInfo = ();
}

pub type Block = generic::Block<Header, UncheckedExtrinsic>;
pub type Header = generic::Header<BlockNumber, BlakeTwo256>;
pub type UncheckedExtrinsic = generic::UncheckedExtrinsic<Address, RuntimeCall, Signature, SignedExtra>;
pub type SignedExtra = (
    frame_system::CheckNonZeroSender<Runtime>,
    frame_system::CheckSpecVersion<Runtime>,
    frame_system::CheckTxVersion<Runtime>,
    frame_system::CheckGenesis<Runtime>,
    frame_system::CheckEra<Runtime>,
    frame_system::CheckNonce<Runtime>,
    frame_system::CheckWeight<Runtime>,
);
pub type Address = sp_runtime::MultiAddress<AccountId, ()>;
pub type SignedPayload = generic::SignedPayload<RuntimeCall, SignedExtra>;
pub type Executive = frame_executive::Executive<
    Runtime,
    Block,
    frame_system::ChainContext<Runtime>,
    Runtime,
    AllPalletsWithSystem,
>;

impl_runtime_apis! {
    impl sp_api::Core<Block> for Runtime {
        fn version() -> RuntimeVersion {
            VERSION
        }

        fn execute_block(block: Block) {
            Executive::execute_block(block);
        }

        fn initialize_block(header: &<Block as BlockT>::Header) {
            Executive::initialize_block(header)
        }
    }

    impl sp_block_builder::BlockBuilder<Block> for Runtime {
        fn apply_extrinsic(extrinsic: <Block as BlockT>::Extrinsic) -> ApplyExtrinsicResult {
            Executive::apply_extrinsic(extrinsic)
        }

        fn finalize_block() -> <Block as BlockT>::Header {
            Executive::finalize_block()
        }

        fn inherent_extrinsics(data: sp_inherents::InherentData) -> Vec<<Block as BlockT>::Extrinsic> {
            data.create_extrinsics()
        }

        fn check_inherents(
            block: Block,
            data: sp_inherents::InherentData,
        ) -> sp_inherents::CheckInherentsResult {
            data.check_extrinsics(&block)
        }
    }

    impl sp_transaction_pool::runtime_api::TaggedTransactionQueue<Block> for Runtime {
        fn validate_transaction(
            source: TransactionSource,
            tx: <Block as BlockT>::Extrinsic,
            block_hash: <Block as BlockT>::Hash,
        ) -> TransactionValidity {
            Executive::validate_transaction(source, tx, block_hash)
        }
    }

    impl sp_offchain::OffchainWorkerApi<Block> for Runtime {
        fn offchain_worker(header: &<Block as BlockT>::Header) {
            Executive::offchain_worker(header)
        }
    }

    impl sp_session::SessionKeys<Block> for Runtime {
        fn generate_session_keys(seed: Option<Vec<u8>>) -> Vec<u8> {
            Vec::new()
        }

        fn decode_session_keys(
            encoded: Vec<u8>,
        ) -> Option<Vec<(Vec<u8>, KeyTypeId)>> {
            None
        }
    }

    impl frame_system_rpc_runtime_api::AccountNonceApi<Block, AccountId, Index> for Runtime {
        fn account_nonce(account: AccountId) -> Index {
            System::account_nonce(account)
        }
    }
}

#[cfg(feature = "std")]
pub fn native_version() -> sp_version::NativeVersion {
    sp_version::NativeVersion {
        runtime_version: VERSION,
        can_author_with: Default::default(),
    }
}

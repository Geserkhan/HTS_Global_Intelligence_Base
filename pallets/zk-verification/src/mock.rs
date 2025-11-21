use crate as pallet_zk_verification;
use frame_support::{
    parameter_types,
    traits::{ConstU16, ConstU32, ConstU64},
};
use frame_system::EnsureRoot;
use sp_core::H256;
use sp_runtime::{
    traits::{BlakeTwo256, IdentityLookup},
    BuildStorage,
};

// Mock 블록 타입 정의
type Block = frame_system::mocking::MockBlock<Test>;

// 테스트용 Mock Runtime 구성
frame_support::construct_runtime!(
    pub enum Test
    {
        System: frame_system,
        ZkVerification: pallet_zk_verification,
    }
);

// System Pallet 설정 파라미터
parameter_types! {
    pub const BlockHashCount: u64 = 250;
    pub const SS58Prefix: u16 = 42;
}

// System Pallet Config 구현
impl frame_system::Config for Test {
    type BaseCallFilter = frame_support::traits::Everything;
    type BlockWeights = ();
    type BlockLength = ();
    type DbWeight = ();
    type RuntimeOrigin = RuntimeOrigin;
    type RuntimeCall = RuntimeCall;
    type Nonce = u64;
    type Hash = H256;
    type Hashing = BlakeTwo256;
    type AccountId = u64;  // AccountId = u64
    type Lookup = IdentityLookup<Self::AccountId>;
    type Block = Block;
    type RuntimeEvent = RuntimeEvent;
    type BlockHashCount = BlockHashCount;
    type Version = ();
    type PalletInfo = PalletInfo;
    type AccountData = ();
    type OnNewAccount = ();
    type OnKilledAccount = ();
    type SystemWeightInfo = ();
    type SS58Prefix = SS58Prefix;
    type OnSetCode = ();
    type MaxConsumers = ConstU32<16>;
}

// ZK Verification Pallet 파라미터
parameter_types! {
    /// 증명 유효 기간: 5,256,000 블록 (~365일, 블록당 6초 기준)
    pub const ProofValidityPeriod: u64 = 5_256_000;
    /// 최대 증명 크기: 2048 바이트
    pub const MaxProofSize: u32 = 2048;
    /// 최대 Nullifier Set 크기: 100,000개
    pub const MaxNullifierSetSize: u32 = 100_000;
}

// ZK Verification Pallet Config 구현
impl pallet_zk_verification::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type AdminOrigin = EnsureRoot<u64>;  // AdminOrigin = EnsureRoot<u64>
    type ProofValidityPeriod = ProofValidityPeriod;
    type MaxProofSize = MaxProofSize;
    type MaxNullifierSetSize = MaxNullifierSetSize;
}

// Mock Runtime Genesis 설정을 기반으로 테스트 환경 빌드
pub fn new_test_ext() -> sp_io::TestExternalities {
    let t = frame_system::GenesisConfig::<Test>::default()
        .build_storage()
        .unwrap();
    let mut ext = sp_io::TestExternalities::new(t);
    // 블록 번호를 1로 초기화 (블록 0은 Genesis)
    ext.execute_with(|| System::set_block_number(1));
    ext
}

// 테스트 헬퍼 함수 및 상수
#[cfg(test)]
mod test_helpers {
    use super::*;

    // 테스트 계정 ID
    pub const ALICE: u64 = 1;
    pub const BOB: u64 = 2;
    pub const CHARLIE: u64 = 3;

    /// 블록을 특정 번호까지 진행시키는 헬퍼 함수
    pub fn run_to_block(n: u64) {
        while System::block_number() < n {
            if System::block_number() > 1 {
                System::on_finalize(System::block_number());
            }
            System::set_block_number(System::block_number() + 1);
            System::on_initialize(System::block_number());
        }
    }

    /// 테스트용 증명 데이터 생성 헬퍼 함수
    pub fn create_test_proof(size: usize) -> Vec<u8> {
        vec![0u8; size]
    }

    /// 테스트용 Nullifier 생성 헬퍼 함수
    pub fn create_test_nullifier(seed: u8) -> H256 {
        H256::from([seed; 32])
    }
}

#[cfg(test)]
pub use test_helpers::*;

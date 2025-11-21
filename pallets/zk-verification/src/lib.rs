#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[cfg(test)]
mod mock;

#[cfg(test)]
mod tests;

#[frame_support::pallet]
pub mod pallet {
    use frame_support::pallet_prelude::*;
    use frame_system::pallet_prelude::*;

    #[pallet::config]
    pub trait Config: frame_system::Config {
        /// The overarching event type.
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;

        /// The origin that can perform administrative operations.
        type AdminOrigin: EnsureOrigin<Self::RuntimeOrigin>;

        /// Proof validity period in blocks (default: ~365 days at 6s/block).
        #[pallet::constant]
        type ProofValidityPeriod: Get<BlockNumberFor<Self>>;

        /// Maximum size of a proof in bytes.
        #[pallet::constant]
        type MaxProofSize: Get<u32>;

        /// Maximum number of nullifiers that can be stored.
        #[pallet::constant]
        type MaxNullifierSetSize: Get<u32>;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    /// Storage for proofs with their metadata
    #[pallet::storage]
    #[pallet::getter(fn proofs)]
    pub type Proofs<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        T::Hash,
        ProofMetadata<T::AccountId, BlockNumberFor<T>>,
        OptionQuery,
    >;

    /// Storage for nullifiers to prevent double-spending
    #[pallet::storage]
    #[pallet::getter(fn nullifiers)]
    pub type Nullifiers<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        T::Hash,
        (),
        OptionQuery,
    >;

    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    pub struct ProofMetadata<AccountId, BlockNumber> {
        pub verifier: AccountId,
        pub submitted_at: BlockNumber,
        pub expires_at: BlockNumber,
        pub is_valid: bool,
    }

    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        /// A proof was successfully verified.
        ProofVerified {
            proof_hash: T::Hash,
            verifier: T::AccountId,
        },
        /// A nullifier was recorded.
        NullifierRecorded {
            nullifier: T::Hash,
        },
        /// A proof has expired.
        ProofExpired {
            proof_hash: T::Hash,
        },
    }

    #[pallet::error]
    pub enum Error<T> {
        /// Proof size exceeds maximum allowed.
        ProofTooLarge,
        /// Nullifier already exists (double-spend attempt).
        NullifierAlreadyExists,
        /// Proof does not exist.
        ProofNotFound,
        /// Proof has expired.
        ProofExpired,
        /// Nullifier set is full.
        NullifierSetFull,
        /// Invalid proof.
        InvalidProof,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        /// Submit and verify a zero-knowledge proof.
        #[pallet::call_index(0)]
        #[pallet::weight(10_000)]
        pub fn submit_proof(
            origin: OriginFor<T>,
            proof: BoundedVec<u8, T::MaxProofSize>,
            nullifier: T::Hash,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            // Check nullifier doesn't exist
            ensure!(
                !Nullifiers::<T>::contains_key(&nullifier),
                Error::<T>::NullifierAlreadyExists
            );

            let current_block = <frame_system::Pallet<T>>::block_number();
            let expires_at = current_block + T::ProofValidityPeriod::get();

            // In a real implementation, verify the proof here
            // For now, we assume all proofs are valid
            let is_valid = true;

            let proof_hash = T::Hashing::hash(&proof);
            let metadata = ProofMetadata {
                verifier: who.clone(),
                submitted_at: current_block,
                expires_at,
                is_valid,
            };

            // Store proof and nullifier
            Proofs::<T>::insert(&proof_hash, metadata);
            Nullifiers::<T>::insert(&nullifier, ());

            Self::deposit_event(Event::ProofVerified {
                proof_hash,
                verifier: who,
            });
            Self::deposit_event(Event::NullifierRecorded { nullifier });

            Ok(())
        }

        /// Invalidate an expired proof (admin only).
        #[pallet::call_index(1)]
        #[pallet::weight(10_000)]
        pub fn invalidate_expired_proof(
            origin: OriginFor<T>,
            proof_hash: T::Hash,
        ) -> DispatchResult {
            T::AdminOrigin::ensure_origin(origin)?;

            let mut metadata = Proofs::<T>::get(&proof_hash)
                .ok_or(Error::<T>::ProofNotFound)?;

            let current_block = <frame_system::Pallet<T>>::block_number();
            ensure!(
                current_block >= metadata.expires_at,
                Error::<T>::ProofExpired
            );

            metadata.is_valid = false;
            Proofs::<T>::insert(&proof_hash, metadata);

            Self::deposit_event(Event::ProofExpired { proof_hash });

            Ok(())
        }
    }
}

use crate::{mock::*, Error, Event};
use frame_support::{assert_noop, assert_ok, BoundedVec};
use sp_core::H256;

#[test]
fn test_mock_runtime_configuration() {
    new_test_ext().execute_with(|| {
        // Verify ProofValidityPeriod is set correctly
        assert_eq!(
            <Test as crate::Config>::ProofValidityPeriod::get(),
            5_256_000
        );

        // Verify MaxProofSize is set correctly
        assert_eq!(<Test as crate::Config>::MaxProofSize::get(), 2048);

        // Verify MaxNullifierSetSize is set correctly
        assert_eq!(
            <Test as crate::Config>::MaxNullifierSetSize::get(),
            100_000
        );
    });
}

#[test]
fn submit_proof_works() {
    new_test_ext().execute_with(|| {
        let proof_data = create_test_proof(1024);
        let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
        let nullifier = create_test_nullifier(1);

        assert_ok!(ZkVerification::submit_proof(
            RuntimeOrigin::signed(ALICE),
            proof.clone(),
            nullifier
        ));

        // Verify events
        System::assert_has_event(
            Event::ProofVerified {
                proof_hash: <Test as frame_system::Config>::Hashing::hash(&proof),
                verifier: ALICE,
            }
            .into(),
        );

        System::assert_has_event(Event::NullifierRecorded { nullifier }.into());
    });
}

#[test]
fn submit_proof_with_duplicate_nullifier_fails() {
    new_test_ext().execute_with(|| {
        let proof_data = create_test_proof(1024);
        let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
        let nullifier = create_test_nullifier(1);

        // First submission should succeed
        assert_ok!(ZkVerification::submit_proof(
            RuntimeOrigin::signed(ALICE),
            proof.clone(),
            nullifier
        ));

        // Second submission with same nullifier should fail
        assert_noop!(
            ZkVerification::submit_proof(
                RuntimeOrigin::signed(BOB),
                proof.clone(),
                nullifier
            ),
            Error::<Test>::NullifierAlreadyExists
        );
    });
}

#[test]
fn proof_size_limit_enforced() {
    new_test_ext().execute_with(|| {
        // Try to create proof larger than MaxProofSize (2048 bytes)
        let large_proof_data = create_test_proof(2049);
        let result: Result<BoundedVec<u8, MaxProofSize>, _> = large_proof_data.try_into();

        // Should fail to convert to BoundedVec
        assert!(result.is_err());
    });
}

#[test]
fn invalidate_expired_proof_works() {
    new_test_ext().execute_with(|| {
        let proof_data = create_test_proof(1024);
        let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
        let nullifier = create_test_nullifier(1);
        let proof_hash = <Test as frame_system::Config>::Hashing::hash(&proof);

        // Submit proof
        assert_ok!(ZkVerification::submit_proof(
            RuntimeOrigin::signed(ALICE),
            proof.clone(),
            nullifier
        ));

        // Advance blocks to expiration (5,256,000 blocks)
        run_to_block(5_256_001);

        // Admin should be able to invalidate expired proof
        assert_ok!(ZkVerification::invalidate_expired_proof(
            RuntimeOrigin::root(),
            proof_hash
        ));

        // Verify event
        System::assert_has_event(Event::ProofExpired { proof_hash }.into());
    });
}

#[test]
fn invalidate_non_expired_proof_fails() {
    new_test_ext().execute_with(|| {
        let proof_data = create_test_proof(1024);
        let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
        let nullifier = create_test_nullifier(1);
        let proof_hash = <Test as frame_system::Config>::Hashing::hash(&proof);

        // Submit proof
        assert_ok!(ZkVerification::submit_proof(
            RuntimeOrigin::signed(ALICE),
            proof.clone(),
            nullifier
        ));

        // Try to invalidate before expiration
        assert_noop!(
            ZkVerification::invalidate_expired_proof(RuntimeOrigin::root(), proof_hash),
            Error::<Test>::ProofExpired
        );
    });
}

#[test]
fn invalidate_proof_requires_admin() {
    new_test_ext().execute_with(|| {
        let proof_data = create_test_proof(1024);
        let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
        let nullifier = create_test_nullifier(1);
        let proof_hash = <Test as frame_system::Config>::Hashing::hash(&proof);

        // Submit proof
        assert_ok!(ZkVerification::submit_proof(
            RuntimeOrigin::signed(ALICE),
            proof.clone(),
            nullifier
        ));

        // Advance to expiration
        run_to_block(5_256_001);

        // Non-admin should not be able to invalidate
        assert_noop!(
            ZkVerification::invalidate_expired_proof(RuntimeOrigin::signed(BOB), proof_hash),
            sp_runtime::DispatchError::BadOrigin
        );
    });
}

#[test]
fn multiple_proofs_with_different_nullifiers_work() {
    new_test_ext().execute_with(|| {
        // Submit multiple proofs with different nullifiers
        for i in 1..=10 {
            let proof_data = create_test_proof(100 * i);
            let proof: BoundedVec<u8, MaxProofSize> = proof_data.try_into().unwrap();
            let nullifier = create_test_nullifier(i as u8);

            assert_ok!(ZkVerification::submit_proof(
                RuntimeOrigin::signed(ALICE),
                proof,
                nullifier
            ));
        }
    });
}

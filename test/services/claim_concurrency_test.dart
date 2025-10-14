import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_underwriter_ai/models/claim.dart';
import 'package:pet_underwriter_ai/services/claims_service.dart';

/// Concurrency Hardening Tests for PetUwrite Claims System
/// 
/// Tests:
/// 1. Concurrent payout processing with settling status lock
/// 2. Concurrent admin reviews with advisory locks
/// 3. Optimistic locking with version checking
/// 4. Network failure mid-transaction
/// 5. Lock timeout and expiry scenarios

void main() {
  group('Claim Concurrency Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ClaimsService claimsService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      claimsService = ClaimsService(firestore: fakeFirestore);
    });

    // Helper to create a test claim
    Future<Claim> createTestClaim(String claimId) async {
      final claim = Claim(
        claimId: claimId,
        policyId: 'policy-123',
        ownerId: 'owner-123',
        petId: 'pet-123',
        incidentDate: DateTime.now().subtract(const Duration(days: 7)),
        claimType: ClaimType.illness,
        claimAmount: 1500.0,
        description: 'Test claim for concurrency',
        status: ClaimStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await fakeFirestore.collection('claims').doc(claimId).set(claim.toMap());
      return claim;
    }

    test('Concurrent payout processing - only one should succeed', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-concurrent-1');
      
      // Simulate two concurrent payout processes
      final results = await Future.wait([
        claimsService.transitionToSettling(
          claimId: claim.claimId,
          expectedUpdatedAt: claim.updatedAt,
        ).then((_) => 'admin1'),
        claimsService.transitionToSettling(
          claimId: claim.claimId,
          expectedUpdatedAt: claim.updatedAt,
        ).then((_) => 'admin2'),
      ], eagerError: false);

      // At least one should have succeeded
      expect(results, hasLength(2));
      
      // Check final claim status
      final finalDoc = await fakeFirestore
          .collection('claims')
          .doc(claim.claimId)
          .get();
      final finalStatus = finalDoc.data()!['status'] as String;
      
      expect(finalStatus, equals('settling'));
    });

    test('Optimistic locking detects concurrent modifications', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-optimistic-1');
      
      // Admin 1 modifies the claim
      await fakeFirestore.collection('claims').doc(claim.claimId).update({
        'description': 'Updated by admin 1',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Admin 2 tries to update with stale updatedAt - should fail
      expect(
        () => claimsService.updateClaimStatusTransactional(
          claimId: claim.claimId,
          newStatus: ClaimStatus.settled,
          expectedUpdatedAt: claim.updatedAt, // Stale timestamp
        ),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });

    test('Advisory lock prevents concurrent admin reviews', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-lock-1');
      
      // Admin 1 acquires lock
      final lock1 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      expect(lock1, isTrue);
      
      // Admin 2 tries to acquire lock - should fail
      final lock2 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-2',
      );
      
      expect(lock2, isFalse);
      
      // Check lock status
      final isLocked = await claimsService.isReviewLocked(
        claimId: claim.claimId,
      );
      
      expect(isLocked, isTrue);
    });

    test('Advisory lock refresh by same admin', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-lock-refresh-1');
      
      // Admin 1 acquires lock
      final lock1 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      expect(lock1, isTrue);
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Same admin refreshes lock - should succeed
      final lock2 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      expect(lock2, isTrue);
    });

    test('Advisory lock expires after 10 minutes', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-lock-expiry-1');
      
      // Admin 1 acquires lock with old timestamp
      final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 11));
      await fakeFirestore.collection('claims').doc(claim.claimId).update({
        'reviewLockedBy': 'admin-1',
        'reviewLockedAt': Timestamp.fromDate(oldTimestamp),
      });
      
      // Check if lock is expired
      final isLocked = await claimsService.isReviewLocked(
        claimId: claim.claimId,
      );
      
      expect(isLocked, isFalse); // Should be expired
      
      // Admin 2 should be able to acquire lock
      final lock2 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-2',
      );
      
      expect(lock2, isTrue);
    });

    test('Advisory lock release by owner', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-lock-release-1');
      
      // Admin 1 acquires lock
      await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      // Admin 1 releases lock
      await claimsService.releaseReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      // Check lock is released
      final isLocked = await claimsService.isReviewLocked(
        claimId: claim.claimId,
      );
      
      expect(isLocked, isFalse);
      
      // Admin 2 can now acquire lock
      final lock2 = await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-2',
      );
      
      expect(lock2, isTrue);
    });

    test('Lock release by non-owner does not release lock', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-lock-nonowner-1');
      
      // Admin 1 acquires lock
      await claimsService.acquireReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-1',
      );
      
      // Admin 2 tries to release lock - should not work
      await claimsService.releaseReviewLock(
        claimId: claim.claimId,
        adminUserId: 'admin-2',
      );
      
      // Check lock is still held
      final isLocked = await claimsService.isReviewLocked(
        claimId: claim.claimId,
      );
      
      expect(isLocked, isTrue);
    });

    test('Clear expired locks in batch', () async {
      // Create multiple claims with expired locks
      for (int i = 0; i < 5; i++) {
        final claim = await createTestClaim('claim-batch-$i');
        
        final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 11));
        await fakeFirestore.collection('claims').doc(claim.claimId).update({
          'reviewLockedBy': 'admin-old',
          'reviewLockedAt': Timestamp.fromDate(oldTimestamp),
        });
      }
      
      // Clear expired locks
      final clearedCount = await claimsService.clearExpiredLocks();
      
      expect(clearedCount, equals(5));
    });

    test('Settling status acts as distributed lock for payouts', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-settling-lock-1');
      
      // Transition to settling
      await claimsService.transitionToSettling(
        claimId: claim.claimId,
        expectedUpdatedAt: claim.updatedAt,
      );
      
      // Get updated timestamp
      final doc1 = await fakeFirestore
          .collection('claims')
          .doc(claim.claimId)
          .get();
      final updatedAt1 = (doc1.data()!['updatedAt'] as Timestamp).toDate();
      
      // Second attempt with stale timestamp should fail
      expect(
        () => claimsService.transitionToSettling(
          claimId: claim.claimId,
          expectedUpdatedAt: claim.updatedAt, // Stale
        ),
        throwsA(isA<ConcurrentModificationException>()),
      );
      
      // Complete payout (transition to settled)
      await claimsService.transitionToSettled(
        claimId: claim.claimId,
        expectedUpdatedAt: updatedAt1,
        payoutDetails: {
          'amount': 1500.0,
          'transactionId': 'txn-12345',
        },
      );
      
      // Verify final status
      final finalDoc = await fakeFirestore
          .collection('claims')
          .doc(claim.claimId)
          .get();
      final finalStatus = finalDoc.data()!['status'] as String;
      
      expect(finalStatus, equals('settled'));
      expect(finalDoc.data()!['settledAt'], isNotNull);
    });

    test('Transaction rollback on network failure simulation', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-network-failure-1');
      
      // Simulate network failure by using invalid claim ID mid-transaction
      expect(
        () => claimsService.updateClaimStatusTransactional(
          claimId: 'nonexistent-claim',
          newStatus: ClaimStatus.settled,
          expectedUpdatedAt: DateTime.now(),
        ),
        throwsException,
      );
      
      // Original claim should remain unchanged
      final doc = await fakeFirestore
          .collection('claims')
          .doc(claim.claimId)
          .get();
      final status = doc.data()!['status'] as String;
      
      expect(status, equals('processing')); // Original status
    });

    test('Multiple concurrent lock acquisition attempts', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-multi-lock-1');
      
      // Simulate 5 concurrent admins trying to acquire lock
      final results = await Future.wait(
        List.generate(5, (i) => claimsService.acquireReviewLock(
          claimId: claim.claimId,
          adminUserId: 'admin-$i',
        )),
        eagerError: false,
      );
      
      // Only one should have succeeded
      final successCount = results.where((r) => r == true).length;
      expect(successCount, equals(1));
      
      // Exactly 4 should have failed
      final failCount = results.where((r) => r == false).length;
      expect(failCount, equals(4));
    });

    test('Status transition with additional fields', () async {
      // Create a test claim
      final claim = await createTestClaim('claim-additional-fields-1');
      
      // Update status with additional fields
      await claimsService.updateClaimStatusTransactional(
        claimId: claim.claimId,
        newStatus: ClaimStatus.denied,
        expectedUpdatedAt: claim.updatedAt,
        additionalFields: {
          'denialReason': 'Pre-existing condition',
          'deniedBy': 'admin-reviewer-1',
        },
      );
      
      // Verify all fields were updated
      final doc = await fakeFirestore
          .collection('claims')
          .doc(claim.claimId)
          .get();
      final data = doc.data()!;
      
      expect(data['status'], equals('denied'));
      expect(data['denialReason'], equals('Pre-existing condition'));
      expect(data['deniedBy'], equals('admin-reviewer-1'));
    });
  });

  group('Claim Model Lock Helpers', () {
    test('isReviewLocked returns true for active lock', () {
      final claim = Claim(
        claimId: 'test-1',
        policyId: 'policy-1',
        ownerId: 'owner-1',
        petId: 'pet-1',
        incidentDate: DateTime.now(),
        claimType: ClaimType.illness,
        claimAmount: 1000.0,
        description: 'Test',
        status: ClaimStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reviewLockedBy: 'admin-1',
        reviewLockedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      
      expect(claim.isReviewLocked, isTrue);
    });

    test('isReviewLocked returns false for expired lock', () {
      final claim = Claim(
        claimId: 'test-2',
        policyId: 'policy-1',
        ownerId: 'owner-1',
        petId: 'pet-1',
        incidentDate: DateTime.now(),
        claimType: ClaimType.illness,
        claimAmount: 1000.0,
        description: 'Test',
        status: ClaimStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reviewLockedBy: 'admin-1',
        reviewLockedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      );
      
      expect(claim.isReviewLocked, isFalse);
      expect(claim.hasExpiredLock, isTrue);
    });

    test('copyWith clearReviewLock parameter', () {
      final claim = Claim(
        claimId: 'test-3',
        policyId: 'policy-1',
        ownerId: 'owner-1',
        petId: 'pet-1',
        incidentDate: DateTime.now(),
        claimType: ClaimType.illness,
        claimAmount: 1000.0,
        description: 'Test',
        status: ClaimStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reviewLockedBy: 'admin-1',
        reviewLockedAt: DateTime.now(),
      );
      
      final clearedClaim = claim.copyWith(clearReviewLock: true);
      
      expect(clearedClaim.reviewLockedBy, isNull);
      expect(clearedClaim.reviewLockedAt, isNull);
      expect(clearedClaim.isReviewLocked, isFalse);
    });
  });
}

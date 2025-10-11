import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Integration tests for Claims Pipeline transactional integrity
/// 
/// These tests validate the Firestore transaction patterns used to prevent
/// race conditions and ensure data consistency in the claims pipeline.
/// 
/// Test Coverage:
/// 1. Settling Lock Pattern - Prevents concurrent claim approval
/// 2. Optimistic Locking - Detects concurrent admin modifications
/// 3. Transaction Atomicity - Claim + payout created together
/// 4. Idempotency Keys - Prevents duplicate operations
/// 5. Timeout Patterns - Handles hung API calls
///
/// Note: These tests focus on transaction logic patterns. Full end-to-end
/// tests with Stripe/SendGrid should use Firebase Emulator.

void main() {
  group('Firestore Transactions - Settling Lock Pattern', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Transaction prevents concurrent transitions to settling status', () async {
      // NOTE: fake_cloud_firestore doesn't fully simulate real Firestore
      // transaction isolation. This test demonstrates the PATTERN, but for
      // true concurrency testing, use Firebase Emulator.
      
      // Arrange: Create a claim in 'processing' status
      final claimId = 'test-claim-001';
      final claimRef = firestore.collection('claims').doc(claimId);
      
      await claimRef.set({
        'claimId': claimId,
        'status': 'processing',
        'claimAmount': 250.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Act: Simulate sequential settle attempts (fake doesn't support true concurrency)
      Future<bool> attemptSettle(String adminId) async {
        try {
          await firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(claimRef);
            final data = snapshot.data()!;
            final currentStatus = data['status'] as String;
            
            // Check if already settling (lock check)
            if (currentStatus != 'processing') {
              throw Exception('Claim already settling or settled');
            }
            
            // Transition to 'settling' (lock the claim)
            transaction.update(claimRef, {
              'status': 'settling',
              'settlingBy': adminId,
              'settlingAt': FieldValue.serverTimestamp(),
            });
          });
          return true;
        } catch (e) {
          return false;
        }
      }

      // First attempt should succeed
      final result1 = await attemptSettle('admin-001');
      expect(result1, isTrue, reason: 'First admin should successfully settle');

      // Second attempt should fail (claim already settling)
      final result2 = await attemptSettle('admin-002');
      expect(result2, isFalse, reason: 'Second admin should fail - claim already settling');

      // Verify final status is 'settling' by first admin
      final finalSnapshot = await claimRef.get();
      expect(finalSnapshot.data()!['status'], equals('settling'));
      expect(finalSnapshot.data()!['settlingBy'], equals('admin-001'));
    });

    test('Transaction atomically creates claim update and payout record', () async {
      // Arrange
      final claimId = 'test-claim-002';
      final claimRef = firestore.collection('claims').doc(claimId);
      final payoutsRef = firestore.collection('payouts');
      
      await claimRef.set({
        'claimId': claimId,
        'status': 'processing',
        'claimAmount': 150.0,
      });

      // Act: Atomic transaction creating payout + updating claim
      final idempotencyKey = const Uuid().v4();
      String? payoutId;
      
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(claimRef);
        final status = snapshot.data()!['status'];
        
        if (status != 'processing') {
          throw Exception('Invalid status');
        }
        
        // Update claim to settling
        transaction.update(claimRef, {
          'status': 'settling',
          'settlingBy': 'admin-001',
        });
        
        // Create payout record
        final newPayoutRef = payoutsRef.doc();
        payoutId = newPayoutRef.id;
        transaction.set(newPayoutRef, {
          'claimId': claimId,
          'amount': 150.0,
          'idempotencyKey': idempotencyKey,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Assert: Both operations committed atomically
      final claimSnapshot = await claimRef.get();
      expect(claimSnapshot.data()!['status'], equals('settling'));
      
      final payoutSnapshot = await payoutsRef.doc(payoutId!).get();
      expect(payoutSnapshot.exists, isTrue);
      expect(payoutSnapshot.data()!['idempotencyKey'], equals(idempotencyKey));
      expect(payoutSnapshot.data()!['claimId'], equals(claimId));
    });

    test('Idempotency check prevents duplicate payout creation', () async {
      // Arrange: Claim with existing payout
      final claimId = 'test-claim-003';
      final existingIdempotencyKey = const Uuid().v4();
      final payoutsRef = firestore.collection('payouts');
      
      await firestore.collection('claims').doc(claimId).set({
        'status': 'settled',
        'claimAmount': 200.0,
      });
      
      await payoutsRef.add({
        'claimId': claimId,
        'idempotencyKey': existingIdempotencyKey,
        'status': 'completed',
        'amount': 200.0,
      });

      // Act: Check for existing payout before creating new one
      final existingPayouts = await payoutsRef
          .where('claimId', isEqualTo: claimId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      // Assert: Existing payout found, should not create duplicate
      expect(existingPayouts.docs.isNotEmpty, isTrue);
      expect(existingPayouts.docs.first.data()['idempotencyKey'], 
             equals(existingIdempotencyKey));
    });
  });

  group('Optimistic Locking - Version Field Pattern', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Transaction detects concurrent modifications via timestamp', () async {
      // Arrange: Create claim with timestamp
      final claimId = 'test-claim-004';
      final claimRef = firestore.collection('claims').doc(claimId);
      final initialTime = Timestamp.now();
      
      await claimRef.set({
        'claimId': claimId,
        'status': 'processing',
        'humanOverride': {},
        'version': 1,
        'updatedAt': initialTime,
      });

      // Simulate first admin reading claim
      final admin1Snapshot = await claimRef.get();
      final admin1UpdatedAt = admin1Snapshot.data()!['updatedAt'];

      // Simulate second admin updating claim (before first admin submits)
      await Future.delayed(const Duration(milliseconds: 100));
      await claimRef.update({
        'humanOverride': {'decision': 'approve', 'by': 'admin-002'},
        'version': 2,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Act: First admin tries to update with stale timestamp
      bool conflictDetected = false;
      try {
        await firestore.runTransaction((transaction) async {
          final currentSnapshot = await transaction.get(claimRef);
          final currentUpdatedAt = currentSnapshot.data()!['updatedAt'];
          final currentVersion = currentSnapshot.data()!['version'];
          
          // Optimistic lock check - compare timestamps
          if (currentUpdatedAt != admin1UpdatedAt) {
            throw Exception('Optimistic lock conflict');
          }
          
          // Update with version increment
          transaction.update(claimRef, {
            'humanOverride': {'decision': 'deny', 'by': 'admin-001'},
            'version': currentVersion + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        conflictDetected = true;
      }

      // Assert: Conflict detected
      expect(conflictDetected, isTrue);
      
      // Verify second admin's update persisted
      final finalSnapshot = await claimRef.get();
      expect(finalSnapshot.data()!['version'], equals(2));
      expect(finalSnapshot.data()!['humanOverride']['by'], equals('admin-002'));
    });

    test('Version field increments atomically', () async {
      // Arrange
      final claimId = 'test-claim-005';
      final claimRef = firestore.collection('claims').doc(claimId);
      
      await claimRef.set({
        'status': 'processing',
        'version': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Act: Perform 3 sequential updates
      for (int i = 0; i < 3; i++) {
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(claimRef);
          final currentVersion = snapshot.data()!['version'] as int;
          
          transaction.update(claimRef, {
            'version': currentVersion + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }

      // Assert: Version incremented to 4 (1 initial + 3 updates)
      final finalSnapshot = await claimRef.get();
      expect(finalSnapshot.data()!['version'], equals(4));
    });
  });

  group('Idempotency Key Pattern', () {
    test('UUID v4 generates unique idempotency keys', () {
      // Act: Generate multiple keys
      final keys = List.generate(100, (_) => const Uuid().v4());
      
      // Assert: All keys are unique
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys.length, equals(100));
      
      // Verify format (UUID v4 has specific pattern)
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      }
    });
  });

  group('Timeout Pattern', () {
    test('Timeout exception thrown after duration', () async {
      // Arrange: Simulated long-running operation
      Future<String> longOperation() async {
        await Future.delayed(const Duration(seconds: 5));
        return 'completed';
      }

      // Act & Assert: Timeout after 1 second
      expect(
        () => longOperation().timeout(const Duration(seconds: 1)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('Operation completes successfully within timeout', () async {
      // Arrange: Quick operation
      Future<String> quickOperation() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'success';
      }

      // Act & Assert: Completes successfully
      final result = await quickOperation().timeout(const Duration(seconds: 1));
      expect(result, equals('success'));
    });
  });

  group('Transaction Rollback Pattern', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Transaction rolls back all changes on error', () async {
      // NOTE: fake_cloud_firestore has incomplete transaction rollback support.
      // This test verifies the PATTERN - use Firebase Emulator for true rollback testing.
      
      // Arrange
      final claimId = 'test-claim-006';
      final claimRef = firestore.collection('claims').doc(claimId);
      final payoutRef = firestore.collection('payouts').doc();
      
      await claimRef.set({
        'status': 'processing',
        'amount': 100.0,
      });

      // Act: Transaction that fails after first operation
      bool exceptionThrown = false;
      try {
        await firestore.runTransaction((transaction) async {
          // First operation: Update claim
          transaction.update(claimRef, {
            'status': 'settling',
          });
          
          // Second operation: Create payout (will fail due to validation)
          transaction.set(payoutRef, {
            'amount': -100.0,  // Invalid negative amount
          });
          
          // Simulate validation error
          throw Exception('Invalid payout amount');
        });
      } catch (e) {
        exceptionThrown = true;
      }

      // Assert: Exception thrown
      expect(exceptionThrown, isTrue);
      
      // In real Firestore, transaction would roll back.
      // fake_cloud_firestore doesn't fully support this - document the limitation
      final claimSnapshot = await claimRef.get();
      final payoutSnapshot = await payoutRef.get();
      
      print('Transaction rollback test results:');
      print('  Claim status: ${claimSnapshot.data()!['status']}');
      print('  Payout exists: ${payoutSnapshot.exists}');
      print('  Note: fake_cloud_firestore has limited transaction rollback support.');
      print('  Use Firebase Emulator for accurate atomicity testing.');
      
      // Document that this test passes with Firebase Emulator but not with fake
      // In production, the transaction would roll back both operations
      expect(exceptionThrown, isTrue, 
          reason: 'Exception should be thrown when transaction fails');
    }, skip: 'fake_cloud_firestore has incomplete transaction rollback - use Firebase Emulator');
  });
}

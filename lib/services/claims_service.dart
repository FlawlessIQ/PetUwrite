import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/claim.dart';
import 'claims_document_uploader.dart';

/// Exception thrown when concurrent modification is detected
class ConcurrentModificationException implements Exception {
  final String message;
  ConcurrentModificationException(this.message);

  @override
  String toString() => 'ConcurrentModificationException: $message';
}

/// Service for operational claim workflows.
/// Handles claim drafts, submission lifecycle helpers, locking, and uploads.
class ClaimsService {
  final FirebaseFirestore _firestore;

  ClaimsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new operational claim (for claim intake flow)
  Future<String> createClaim(Claim claim) async {
    try {
      final claimRef = _firestore.collection('claims').doc(claim.claimId);

      // Important: Firestore rules may deny reading non-existent claim docs.
      // Use an upsert write without a pre-read. For updates, createdAt must
      // remain stable (the caller is responsible for keeping claim.createdAt
      // consistent).
      final data = claim.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await claimRef.set(data, SetOptions(merge: true));
      return claim.claimId;
    } catch (e) {
      throw Exception('Failed to create claim: $e');
    }
  }

  /// Save draft claim
  Future<void> saveDraftClaim(Claim claim) async {
    try {
      final claimRef = _firestore.collection('claims').doc(claim.claimId);

      // Avoid reading before writing (reads of missing docs may be denied).
      // Upsert with merge so we can create drafts and update them later.
      // Firestore rules enforce createdAt immutability, so caller must keep
      // claim.createdAt stable across saves.
      final data = claim.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await claimRef.set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save draft claim: $e');
    }
  }

  // ============================================================================
  // CONCURRENCY-SAFE CLAIM STATUS UPDATES WITH TRANSACTIONS
  // ============================================================================

  /// Update claim status with optimistic locking using updatedAt timestamp
  /// Throws ConcurrentModificationException if claim was modified by another process
  Future<void> updateClaimStatusTransactional({
    required String claimId,
    required ClaimStatus newStatus,
    required DateTime expectedUpdatedAt,
    Map<String, dynamic>? additionalFields,
  }) async {
    final claimRef = _firestore.collection('claims').doc(claimId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(claimRef);

        if (!snapshot.exists) {
          throw Exception('Claim $claimId not found');
        }

        final currentData = snapshot.data()!;
        final currentUpdatedAt = (currentData['updatedAt'] as Timestamp)
            .toDate();

        // Optimistic locking check
        if (currentUpdatedAt != expectedUpdatedAt) {
          throw ConcurrentModificationException(
            'Claim was modified by another process. '
            'Expected updatedAt: $expectedUpdatedAt, '
            'Actual updatedAt: $currentUpdatedAt',
          );
        }

        // Prepare update data
        final updateData = {
          'status': newStatus.value,
          'updatedAt': FieldValue.serverTimestamp(),
          ...?additionalFields,
        };

        transaction.update(claimRef, updateData);
      });
    } catch (e) {
      if (e is ConcurrentModificationException) {
        rethrow;
      }
      throw Exception('Failed to update claim status: $e');
    }
  }

  /// Transition claim to settling status (used as lock during payout processing)
  /// This prevents concurrent payout attempts
  Future<void> transitionToSettling({
    required String claimId,
    required DateTime expectedUpdatedAt,
  }) async {
    await updateClaimStatusTransactional(
      claimId: claimId,
      newStatus: ClaimStatus.settling,
      expectedUpdatedAt: expectedUpdatedAt,
    );
  }

  /// Transition claim from settling to settled (completes payout)
  Future<void> transitionToSettled({
    required String claimId,
    required DateTime expectedUpdatedAt,
    Map<String, dynamic>? payoutDetails,
  }) async {
    await updateClaimStatusTransactional(
      claimId: claimId,
      newStatus: ClaimStatus.settled,
      expectedUpdatedAt: expectedUpdatedAt,
      additionalFields: {
        'settledAt': FieldValue.serverTimestamp(),
        if (payoutDetails != null) 'payoutDetails': payoutDetails,
      },
    );
  }

  // ============================================================================
  // ADVISORY LOCK SYSTEM FOR ADMIN EXCEPTION CONTROLS (10-minute timeout)
  // ============================================================================

  /// Acquire an exception-control lock for admin user.
  /// Returns true if lock acquired, false if already locked by another admin
  Future<bool> acquireReviewLock({
    required String claimId,
    required String adminUserId,
  }) async {
    final claimRef = _firestore.collection('claims').doc(claimId);

    try {
      final result = await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(claimRef);

        if (!snapshot.exists) {
          throw Exception('Claim $claimId not found');
        }

        final data = snapshot.data()!;
        final reviewLockedBy = data['reviewLockedBy'] as String?;
        final reviewLockedAt = data['reviewLockedAt'] as Timestamp?;

        // Check if lock exists and is not expired
        if (reviewLockedBy != null && reviewLockedAt != null) {
          final lockTime = reviewLockedAt.toDate();
          final lockExpiry = lockTime.add(const Duration(minutes: 10));
          final now = DateTime.now();

          // Lock is still valid
          if (now.isBefore(lockExpiry)) {
            // Already locked by same user - allow (lock refresh)
            if (reviewLockedBy == adminUserId) {
              transaction.update(claimRef, {
                'reviewLockedAt': FieldValue.serverTimestamp(),
              });
              return true;
            }
            // Locked by different user
            return false;
          }
          // Lock expired - can acquire
        }

        // Acquire lock
        transaction.update(claimRef, {
          'reviewLockedBy': adminUserId,
          'reviewLockedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      return result;
    } catch (e) {
      throw Exception('Failed to acquire exception lock: $e');
    }
  }

  /// Release exception-control lock
  Future<void> releaseReviewLock({
    required String claimId,
    required String adminUserId,
  }) async {
    final claimRef = _firestore.collection('claims').doc(claimId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(claimRef);

        if (!snapshot.exists) {
          throw Exception('Claim $claimId not found');
        }

        final data = snapshot.data()!;
        final reviewLockedBy = data['reviewLockedBy'] as String?;

        // Only release if locked by this user
        if (reviewLockedBy == adminUserId) {
          transaction.update(claimRef, {
            'reviewLockedBy': FieldValue.delete(),
            'reviewLockedAt': FieldValue.delete(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to release exception lock: $e');
    }
  }

  /// Check if claim is currently locked for exception control
  Future<bool> isReviewLocked({required String claimId}) async {
    try {
      final snapshot = await _firestore.collection('claims').doc(claimId).get();

      if (!snapshot.exists) {
        throw Exception('Claim $claimId not found');
      }

      final data = snapshot.data()!;
      final reviewLockedBy = data['reviewLockedBy'] as String?;
      final reviewLockedAt = data['reviewLockedAt'] as Timestamp?;

      if (reviewLockedBy == null || reviewLockedAt == null) {
        return false;
      }

      final lockTime = reviewLockedAt.toDate();
      final lockExpiry = lockTime.add(const Duration(minutes: 10));
      final now = DateTime.now();

      return now.isBefore(lockExpiry);
    } catch (e) {
      throw Exception('Failed to check exception lock: $e');
    }
  }

  /// Clear expired exception-control locks (called by reconciliation function)
  Future<int> clearExpiredLocks() async {
    try {
      final now = DateTime.now();
      final expiryThreshold = now.subtract(const Duration(minutes: 10));

      final snapshot = await _firestore
          .collection('claims')
          .where(
            'reviewLockedAt',
            isLessThan: Timestamp.fromDate(expiryThreshold),
          )
          .get();

      int clearedCount = 0;

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'reviewLockedBy': FieldValue.delete(),
          'reviewLockedAt': FieldValue.delete(),
        });
        clearedCount++;
      }

      return clearedCount;
    } catch (e) {
      throw Exception('Failed to clear expired locks: $e');
    }
  }

  /// Upload claim document to Firebase Storage (for mobile using file path)
  Future<String> uploadClaimDocument(String filePath, String claimId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = filePath.split('/').last;
      final fileRef = storageRef.child('claims/$claimId/$timestamp-$fileName');

      await uploadFileToStorageRef(
        fileRef,
        filePath,
        metadata: SettableMetadata(contentType: _getContentType(fileName)),
      );

      return await fileRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Upload claim document and return both download URL and storage path.
  ///
  /// This enables server-side automation to read the file from Storage
  /// reliably (without depending on tokenized download URLs).
  Future<Map<String, dynamic>> uploadClaimDocumentWithMetadata(
    String filePath,
    String claimId,
  ) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = filePath.split('/').last;
      final fileRef = storageRef.child('claims/$claimId/$timestamp-$fileName');

      await uploadFileToStorageRef(
        fileRef,
        filePath,
        metadata: SettableMetadata(contentType: _getContentType(fileName)),
      );

      final downloadUrl = await fileRef.getDownloadURL();
      return {
        'downloadUrl': downloadUrl,
        'storagePath': fileRef.fullPath,
        'fileName': fileName,
        'contentType': _getContentType(fileName),
      };
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Upload claim document to Firebase Storage from bytes (for web)
  Future<String> uploadClaimDocumentFromBytes(
    Uint8List bytes,
    String fileName,
    String claimId,
  ) async {
    try {
      // Use Firebase Storage for web
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileRef = storageRef.child('claims/$claimId/$timestamp-$fileName');

      // Upload the file bytes
      final uploadTask = await fileRef.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(fileName)),
      );

      // Get download URL
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Upload claim document from bytes and return both download URL and storage path.
  Future<Map<String, dynamic>> uploadClaimDocumentFromBytesWithMetadata(
    Uint8List bytes,
    String fileName,
    String claimId,
  ) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileRef = storageRef.child('claims/$claimId/$timestamp-$fileName');

      final uploadTask = await fileRef.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(fileName)),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return {
        'downloadUrl': downloadUrl,
        'storagePath': uploadTask.ref.fullPath,
        'fileName': fileName,
        'contentType': _getContentType(fileName),
      };
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'application/octet-stream';
    }
  }
}

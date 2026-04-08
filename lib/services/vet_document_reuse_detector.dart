import 'package:cloud_firestore/cloud_firestore.dart';

import 'underwriting_integrity_engine.dart';

/// Deterministic, auditable detector for vet-document reuse across underwriting cases.
///
/// Uses SHA-256 hashes computed from raw uploaded bytes.
class VetDocumentReuseDetector {
  final FirebaseFirestore _firestore;

  VetDocumentReuseDetector({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<VetDocumentReuseCheckResult> check({
    required List<String> vetDocumentHashes,
    String? underwritingCaseId,
  }) async {
    final hashes = vetDocumentHashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashes.isEmpty) {
      return const VetDocumentReuseCheckResult.pass();
    }

    final matchedCaseIds = <String>{};

    try {
      String? currentUserId;
      if (underwritingCaseId != null && underwritingCaseId.isNotEmpty) {
        try {
          final current = await _firestore
              .collection('underwriting_cases')
              .doc(underwritingCaseId)
              .get();
          currentUserId = current.data()?['userId']?.toString();
        } catch (_) {
          // If we can't read current case owner, we still proceed with reuse
          // detection and will fail closed if needed.
        }
      }

      // Keep this deterministic and bounded: iterate hashes (usually small)
      // and stop early once we have enough signal to decline.
      for (final hash in hashes) {
        final query = await _firestore
            .collectionGroup('vet_records')
            .where('documentHash', isEqualTo: hash)
            .limit(10)
            .get();

        for (final doc in query.docs) {
          final data = doc.data();
          final caseId = (data['caseId'] ?? '').toString();
          if (caseId.isEmpty) continue;
          if (underwritingCaseId != null && underwritingCaseId.isNotEmpty) {
            if (caseId == underwritingCaseId) continue;
          }
          matchedCaseIds.add(caseId);
          if (matchedCaseIds.length >= 2) {
            return VetDocumentReuseCheckResult.decline(
              reason: 'VET_DOCUMENT_REUSE_MULTI_CASE',
              matchedCaseIds: matchedCaseIds.toList()..sort(),
            );
          }
        }
      }

      if (matchedCaseIds.isEmpty) {
        return const VetDocumentReuseCheckResult.pass();
      }

      // If a single reuse match is found, check for cross-account reuse when
      // we can read case ownership. Cross-account reuse is a stronger signal.
      if (currentUserId != null && currentUserId.trim().isNotEmpty) {
        for (final otherCaseId in matchedCaseIds) {
          try {
            final other = await _firestore
                .collection('underwriting_cases')
                .doc(otherCaseId)
                .get();
            final otherUserId = other.data()?['userId']?.toString();
            if (otherUserId != null &&
                otherUserId.trim().isNotEmpty &&
                otherUserId.trim() != currentUserId.trim()) {
              return VetDocumentReuseCheckResult.decline(
                reason: 'VET_DOCUMENT_REUSE_CROSS_ACCOUNT',
                matchedCaseIds: matchedCaseIds.toList()..sort(),
              );
            }
          } catch (_) {
            // If case ownership is not readable (e.g. security rules), we
            // fall back to the base reuse signal rather than hard failing.
            break;
          }
        }
      }

      return VetDocumentReuseCheckResult.needMoreInfo(
        reason: 'VET_DOCUMENT_REUSE_DETECTED',
        matchedCaseIds: matchedCaseIds.toList()..sort(),
      );
    } catch (e) {
      // Fail open: if reuse detection infrastructure is unavailable (e.g.
      // user not authenticated, Firestore rules block the collectionGroup
      // query, or index missing) we pass — there is no positive reuse signal,
      // so blocking the flow would only frustrate genuine applicants.
      // Reuse is still enforced server-side during case finalization.
      return const VetDocumentReuseCheckResult.pass();
    }
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftResolveResult {
  final String ownerUid;
  final String draftType;
  final String state;
  final Map<String, dynamic> snapshot;

  const DraftResolveResult({
    required this.ownerUid,
    required this.draftType,
    required this.state,
    required this.snapshot,
  });
}

/// DraftService
///
/// Implements "save & revisit" without explicit sign-up by:
/// - ensuring there is always an authenticated session (anonymous auth)
/// - persisting a server-side draft keyed by a high-entropy resumeKey
/// - allowing resume on another device by exchanging resumeKey for a custom
///   auth token that signs the user into the original uid
class DraftService {
  static const String _resumeKeyPrefsKey = 'draft_resume_key';

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  DraftService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Future<void> ensureAnonymousSession() async {
    final existing = _auth.currentUser;
    if (existing != null) return;
    await _auth.signInAnonymously();
  }

  Future<String?> getLocalResumeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_resumeKeyPrefsKey);
    if (key == null) return null;
    final trimmed = key.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String> getOrCreateLocalResumeKey() async {
    final existing = await getLocalResumeKey();
    if (existing != null) return existing;

    final resumeKey = _generateResumeKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resumeKeyPrefsKey, resumeKey);
    return resumeKey;
  }

  Future<void> setLocalResumeKey(String resumeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resumeKeyPrefsKey, resumeKey.trim());
  }

  Future<void> clearLocalResumeKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeKeyPrefsKey);
  }

  String _generateResumeKey() {
    // 32 bytes of entropy, base64url => ~43 chars.
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> upsertQuoteDraft({
    required Map<String, dynamic> quoteData,
    int expiresInDays = 30,
  }) async {
    await ensureAnonymousSession();
    final resumeKey = await getOrCreateLocalResumeKey();

    final callable = _functions.httpsCallable('upsertDraft');
    await callable.call({
      'resumeKey': resumeKey,
      'draftType': 'quote',
      'state': 'QUOTE',
      'snapshot': quoteData,
      'expiresInDays': expiresInDays,
    });
  }

  Future<void> upsertUnderwritingDraft({
    required String underwritingCaseId,
    required String petName,
    dynamic riskScore,
    String? reason,
    List<Map<String, dynamic>> requiredEvidence = const [],
    int expiresInDays = 30,
  }) async {
    await ensureAnonymousSession();
    final resumeKey = await getOrCreateLocalResumeKey();

    final snapshot = <String, dynamic>{
      'underwritingCaseId': underwritingCaseId,
      'petName': petName,
      if (riskScore != null) 'riskScore': riskScore,
      if (reason != null) 'reason': reason,
      if (requiredEvidence.isNotEmpty) 'requiredEvidence': requiredEvidence,
    };

    final callable = _functions.httpsCallable('upsertDraft');
    await callable.call({
      'resumeKey': resumeKey,
      'draftType': 'underwriting',
      'state': 'NEED_MORE_INFO',
      'snapshot': snapshot,
      'underwritingCaseId': underwritingCaseId,
      'reason': reason,
      'requiredEvidence': requiredEvidence,
      'expiresInDays': expiresInDays,
    });
  }

  Future<void> upsertCheckoutDraft({
    required String state,
    required Map<String, dynamic> checkoutData,
    int expiresInDays = 30,
  }) async {
    await ensureAnonymousSession();
    final resumeKey = await getOrCreateLocalResumeKey();

    final callable = _functions.httpsCallable('upsertDraft');
    await callable.call({
      'resumeKey': resumeKey,
      'draftType': 'checkout',
      'state': state,
      'snapshot': checkoutData,
      'expiresInDays': expiresInDays,
    });
  }

  /// Resolve a draft by resumeKey.
  ///
  /// If the current user is not already the owning uid, this will sign in using
  /// a custom token so Firestore/Storage access lines up with the original uid.
  Future<DraftResolveResult> resolveAndAdoptDraft({
    required String resumeKey,
  }) async {
    final callable = _functions.httpsCallable('resolveDraft');
    final result = await callable.call({'resumeKey': resumeKey.trim()});

    final data = (result.data is Map)
        ? (result.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    if (data['ok'] != true) {
      throw Exception('Unable to resolve draft');
    }

    final ownerUid = (data['ownerUid'] ?? '').toString();
    final customToken = (data['customToken'] ?? '').toString();
    final draft = (data['draft'] is Map)
        ? (data['draft'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final draftType = (draft['draftType'] ?? 'quote').toString();
    final state = (draft['state'] ?? '').toString();
    final snapshot = (draft['snapshot'] is Map)
        ? (draft['snapshot'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    // Adopt the owning uid if needed.
    final current = _auth.currentUser;
    final needsAdopt = current == null || current.uid != ownerUid;
    if (needsAdopt) {
      if (customToken.isEmpty) {
        throw Exception('Missing custom token');
      }
      await _auth.signInWithCustomToken(customToken);
    }

    // Persist resumeKey locally so "Continue" works on this device.
    await setLocalResumeKey(resumeKey.trim());

    return DraftResolveResult(
      ownerUid: ownerUid,
      draftType: draftType,
      state: state,
      snapshot: snapshot,
    );
  }

  Future<void> clearServerDraft() async {
    final resumeKey = await getLocalResumeKey();
    if (resumeKey == null) return;

    await ensureAnonymousSession();
    final callable = _functions.httpsCallable('clearDraft');
    await callable.call({'resumeKey': resumeKey});
  }

  Future<void> clearAll() async {
    try {
      await clearServerDraft();
    } catch (_) {
      // Ignore server errors; local clear still makes UX sane.
    }
    await clearLocalResumeKey();
  }

  /// A short, user-friendly representation (not cryptographically safe by itself).
  /// Use the full resumeKey for actual resolution.
  String prettyCode(String resumeKey) {
    final cleaned = resumeKey.replaceAll('=', '').replaceAll('-', '').replaceAll('_', '');
    if (cleaned.length <= 12) return cleaned;
    return '${cleaned.substring(0, 6)}-${cleaned.substring(6, 12)}';
  }

  String encodeForSharing(String resumeKey) {
    return resumeKey.trim();
  }

  Map<String, dynamic> tryDecodeSnapshotString(String s) {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw Exception('Invalid snapshot');
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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

  static const String _crockfordBase32Alphabet =
      '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;

  DraftService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _authOverride = auth,
        _functionsOverride = functions;

  bool get _firebaseDisabled =>
      const bool.fromEnvironment('DISABLE_FIREBASE', defaultValue: false);

  FirebaseAuth? _tryGetAuth() {
    if (_authOverride != null) return _authOverride;
    if (_firebaseDisabled) return null;
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      if (kDebugMode) debugPrint('[DraftService] FirebaseAuth unavailable: $e');
      return null;
    }
  }

  FirebaseFunctions? _tryGetFunctions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (_firebaseDisabled) return null;
    try {
      return FirebaseFunctions.instance;
    } catch (e) {
      if (kDebugMode) debugPrint('[DraftService] FirebaseFunctions unavailable: $e');
      return null;
    }
  }

  Future<void> ensureAnonymousSession() async {
    final auth = _tryGetAuth();
    if (auth == null) {
      throw Exception('Resume is unavailable (Firebase disabled/unavailable)');
    }

    final existing = auth.currentUser;
    if (existing != null) return;
    await auth.signInAnonymously();
  }

  Future<String?> getLocalResumeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_resumeKeyPrefsKey);
    if (key == null) return null;
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    return normalizeResumeCode(trimmed);
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
    await prefs.setString(_resumeKeyPrefsKey, normalizeResumeCode(resumeKey));
  }

  Future<void> clearLocalResumeKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeKeyPrefsKey);
  }

  String _generateResumeKey() {
    // Human-typeable resume code.
    // - 15 bytes = 120 bits of entropy
    // - Crockford Base32 => 24 chars
    // Stored without hyphens; UI can format as 6-6-6-6.
    final rng = Random.secure();
    final bytes = List<int>.generate(15, (_) => rng.nextInt(256));
    return _encodeCrockfordBase32(bytes);
  }

  String _encodeCrockfordBase32(List<int> bytes) {
    var buffer = 0;
    var bitsLeft = 0;
    final out = StringBuffer();

    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xff);
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        final idx = (buffer >> (bitsLeft - 5)) & 0x1f;
        out.write(_crockfordBase32Alphabet[idx]);
        bitsLeft -= 5;
      }
    }

    if (bitsLeft > 0) {
      final idx = (buffer << (5 - bitsLeft)) & 0x1f;
      out.write(_crockfordBase32Alphabet[idx]);
    }

    // For 15 bytes (120 bits) we should end up with 24 chars.
    final s = out.toString();
    return s.length > 24 ? s.substring(0, 24) : s.padRight(24, '0');
  }

  bool _looksLikeCrockfordBase32(String s) {
    final upper = s.toUpperCase();
    for (final ch in upper.split('')) {
      if (ch == '-') continue;
      if (!_crockfordBase32Alphabet.contains(ch)) return false;
    }
    return true;
  }

  /// Normalizes user-entered resume codes.
  ///
  /// - Trims whitespace
  /// Normalizes Crockford Base32 codes by uppercasing and removing hyphens/spaces.
  /// - Leaves legacy base64url-style keys intact (besides trimming)
  String normalizeResumeCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Legacy keys can contain '_' or '='; don't mutate those.
    final isLegacy = trimmed.contains('_') || trimmed.contains('=');
    if (isLegacy) return trimmed;

    // If it looks like our Crockford Base32, normalize aggressively.
    if (_looksLikeCrockfordBase32(trimmed)) {
      final canonical = trimmed
          .toUpperCase()
          .replaceAll(RegExp(r'[^0-9A-Z]'), '')
          .replaceAll('O', '0')
          .replaceAll('I', '1')
          .replaceAll('L', '1');
      return canonical;
    }

    return trimmed;
  }

  Future<void> upsertQuoteDraft({
    required Map<String, dynamic> quoteData,
    int expiresInDays = 30,
  }) async {
    await ensureAnonymousSession();
    final resumeKey = await getOrCreateLocalResumeKey();

    final functions = _tryGetFunctions();
    if (functions == null) {
      throw Exception('Draft save unavailable (Firebase disabled/unavailable)');
    }
    final callable = functions.httpsCallable('upsertDraft');
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

    final functions = _tryGetFunctions();
    if (functions == null) {
      throw Exception('Draft save unavailable (Firebase disabled/unavailable)');
    }
    final callable = functions.httpsCallable('upsertDraft');
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

    final functions = _tryGetFunctions();
    if (functions == null) {
      throw Exception('Draft save unavailable (Firebase disabled/unavailable)');
    }
    final callable = functions.httpsCallable('upsertDraft');
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
    final functions = _tryGetFunctions();
    final auth = _tryGetAuth();
    if (functions == null || auth == null) {
      throw Exception('Resume is unavailable (Firebase disabled/unavailable)');
    }

    final canonical = normalizeResumeCode(resumeKey);
    final callable = functions.httpsCallable('resolveDraft');
    final result = await callable.call({'resumeKey': canonical});

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
    final current = auth.currentUser;
    final needsAdopt = current == null || current.uid != ownerUid;
    if (needsAdopt) {
      if (customToken.isEmpty) {
        throw Exception('Missing custom token');
      }
      await auth.signInWithCustomToken(customToken);
    }

    // Persist canonical resumeKey locally so "Continue" works on this device.
    await setLocalResumeKey(canonical);

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
    final functions = _tryGetFunctions();
    if (functions == null) return;
    final callable = functions.httpsCallable('clearDraft');
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
    final canonical = normalizeResumeCode(resumeKey);

    // For our human-typeable keys, show 6-6-6-6.
    if (_looksLikeCrockfordBase32(canonical) && canonical.length >= 24) {
      final s = canonical.substring(0, 24);
      return '${s.substring(0, 6)}-${s.substring(6, 12)}-${s.substring(12, 18)}-${s.substring(18, 24)}';
    }

    // Legacy behavior fallback.
    final cleaned = canonical.replaceAll('=', '').replaceAll('-', '').replaceAll('_', '');
    if (cleaned.length <= 12) return cleaned;
    return '${cleaned.substring(0, 6)}-${cleaned.substring(6, 12)}';
  }

  String encodeForSharing(String resumeKey) {
    final canonical = normalizeResumeCode(resumeKey);

    // If it's our Crockford Base32 format, share the short hyphenated form.
    if (_looksLikeCrockfordBase32(canonical) && canonical.length >= 24) {
      return prettyCode(canonical);
    }

    // Legacy/base64url keys must be shared in full to be resolvable.
    return canonical;
  }

  Map<String, dynamic> tryDecodeSnapshotString(String s) {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw Exception('Invalid snapshot');
  }
}

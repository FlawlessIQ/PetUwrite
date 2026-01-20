import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'referrer_host.dart';

class MarketingAttributionService {
  static final MarketingAttributionService _instance =
      MarketingAttributionService._internal();
  factory MarketingAttributionService() => _instance;
  MarketingAttributionService._internal();

  static const _sessionIdKey = 'marketing_attribution_session_id';
  static const _channelIdKey = 'marketing_attribution_channel_id';

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? _sessionId;
  String? _channelId;

  String? get sessionId => _sessionId;
  String? get channelId => _channelId;

  Future<void> ensureSessionStarted() async {
    if (_sessionId != null) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_sessionIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      _sessionId = existing.trim();
      _channelId = (prefs.getString(_channelIdKey) ?? '').trim();
      if (_channelId != null && _channelId!.isEmpty) _channelId = null;
      if (kDebugMode) {
        debugPrint(
          '[MarketingAttribution] Reusing sessionId=$_sessionId channelId=$_channelId',
        );
      }
      return;
    }

    final uri = Uri.base;
    final qp = uri.queryParameters;

    final payload = <String, dynamic>{
      'utmSource': qp['utm_source'] ?? qp['utmSource'],
      'utmMedium': qp['utm_medium'] ?? qp['utmMedium'],
      'utmCampaign': qp['utm_campaign'] ?? qp['utmCampaign'],
      'utmContent': qp['utm_content'] ?? qp['utmContent'],
      'utmTerm': qp['utm_term'] ?? qp['utmTerm'],
      'referrerHost': getReferrerHost(),
      'landingPath': uri.path,
    };

    try {
      final callable = _functions.httpsCallable('startAttributionSession');
      final resp = await callable.call(payload);
      final data = (resp.data is Map)
          ? (resp.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final sessionId = (data['sessionId'] ?? '').toString().trim();
      final channelId = (data['channelId'] ?? '').toString().trim();

      if (sessionId.isEmpty) return;

      _sessionId = sessionId;
      _channelId = channelId.isEmpty ? null : channelId;

      if (kDebugMode) {
        debugPrint(
          '[MarketingAttribution] Started sessionId=$_sessionId channelId=$_channelId utm_source=${payload['utmSource']} utm_campaign=${payload['utmCampaign']} referrer=${payload['referrerHost']} path=${payload['landingPath']}',
        );
      }

      await prefs.setString(_sessionIdKey, sessionId);
      if (_channelId != null) {
        await prefs.setString(_channelIdKey, _channelId!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MarketingAttribution] Failed to start session: $e');
      }
      // Best-effort only.
    }
  }

  Future<void> trackEvent(
    String type, {
    String? policyId,
    String? quoteId,
    String? underwritingCaseId,
    String? code,
    double? premium,
    double? discountAmount,
    double? spend,
    Map<String, dynamic>? metadata,
  }) async {
    await ensureSessionStarted();

    try {
      final callable = _functions.httpsCallable('trackMarketingEvent');
      await callable.call({
        'type': type,
        'sessionId': _sessionId,
        'channelId': _channelId,
        if (policyId != null) 'policyId': policyId,
        if (quoteId != null) 'quoteId': quoteId,
        if (underwritingCaseId != null)
          'underwritingCaseId': underwritingCaseId,
        if (code != null) 'code': code,
        if (premium != null) 'premium': premium,
        if (discountAmount != null) 'discountAmount': discountAmount,
        if (spend != null) 'spend': spend,
        if (metadata != null) 'metadata': metadata,
      });
      if (kDebugMode) {
        debugPrint(
          '[MarketingAttribution] Sent event=$type sessionId=$_sessionId channelId=$_channelId code=$code policyId=$policyId quoteId=$quoteId underwritingCaseId=$underwritingCaseId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MarketingAttribution] Failed event=$type sessionId=$_sessionId channelId=$_channelId: $e',
        );
      }
      // Best-effort only.
    }
  }

  Future<void> trackOnce(String onceKey, Future<void> Function() send) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(onceKey) == true) return;
    try {
      await send();
      await prefs.setBool(onceKey, true);
    } catch (_) {
      // Leave unset so it can retry later.
    }
  }

  Future<void> trackQuoteStartedOnce() async {
    await ensureSessionStarted();
    final sid = _sessionId;
    if (sid == null) return;
    await trackOnce(
      'marketing_sent_${sid}_quote_started',
      () => trackEvent('quote_started'),
    );
  }

  Future<void> trackCheckoutStartedOnce() async {
    await ensureSessionStarted();
    final sid = _sessionId;
    if (sid == null) return;
    await trackOnce(
      'marketing_sent_${sid}_checkout_started',
      () => trackEvent('checkout_started'),
    );
  }

  Future<void> trackUnderwritingSubmittedOnce({
    required String underwritingCaseId,
  }) async {
    await ensureSessionStarted();
    final sid = _sessionId;
    if (sid == null) return;

    final caseId = underwritingCaseId.trim();
    if (caseId.isEmpty) return;

    await trackOnce(
      'marketing_sent_${sid}_underwriting_submitted_$caseId',
      () => trackEvent('underwriting_submitted', underwritingCaseId: caseId),
    );
  }
}

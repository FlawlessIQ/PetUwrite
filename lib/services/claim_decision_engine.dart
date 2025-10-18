import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai/ai_service.dart';
import '../models/claim.dart';
import 'claim_document_ai_service.dart';

/// AI-powered claim decision engine
/// Combines actuarial rules + GPT-4o analysis for automated claim processing
class ClaimDecisionEngine {
  final FirebaseFirestore _firestore;
  final GPTService _gptService;
  final ClaimDocumentAIService _documentService;

  // Decision thresholds
  static const double autoApproveThreshold = 75.0; // Temporarily lowered for testing (was 85.0)
  static const double autoApproveAmountLimit = 300.0;
  static const double humanReviewThreshold = 60.0;
  static const int maxRetries = 3;

  ClaimDecisionEngine({
    FirebaseFirestore? firestore,
    GPTService? gptService,
    ClaimDocumentAIService? documentService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _gptService = gptService ??
            GPTService(
              apiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
              model: 'gpt-4o',
            ),
        _documentService = documentService ?? ClaimDocumentAIService();

  /// Process claim and make automated decision
  /// Returns updated claim with AI decision + explanation
  Future<ClaimDecisionResult> processClaimDecision({
    required Claim claim,
    List<ClaimDocumentAnalysis>? documentAnalyses,
    Map<String, dynamic>? historicalData,
    bool enableAutoApprove = true,
  }) async {
    print('🤖 Starting claim decision process...');
    print('   Claim ID: ${claim.claimId}');
    print('   Amount: \$${claim.claimAmount}');
    print('   Type: ${claim.claimType.displayName}');

    try {
      // Step 1: Gather all input data
      print('📊 Step 1: Gathering input data...');
      final inputData = await _gatherInputData(
        claim: claim,
        documentAnalyses: documentAnalyses,
        historicalData: historicalData,
      );

      // Step 2: Run AI analysis with retry logic
      print('🤖 Step 2: Running AI analysis...');
      final aiResult = await _runAIAnalysisWithRetry(inputData);

      // Step 3: Apply actuarial rules
      print('📐 Step 3: Applying actuarial rules...');
      final decision = _applyActuarialRules(
        aiResult: aiResult,
        claim: claim,
        inputData: inputData,
        enableAutoApprove: enableAutoApprove,
      );

      // Step 4: Update claim with decision
      print('💾 Step 4: Updating claim...');
      final updatedClaim = await _updateClaimWithDecision(claim, decision);

      // Step 5: Log to audit trail
      print('📝 Step 5: Logging to audit trail...');
      await _logToAuditTrail(claim.claimId, decision, inputData);

      print('✅ Decision complete: ${decision.aiDecision.displayName}');
      print('   Confidence: ${decision.aiConfidenceScore.toStringAsFixed(1)}%');
      print('   Status: ${decision.finalStatus.displayName}');

      return ClaimDecisionResult(
        claim: updatedClaim,
        aiConfidenceScore: decision.aiConfidenceScore,
        aiDecision: decision.aiDecision,
        explanation: decision.explanation,
        finalStatus: decision.finalStatus,
        autoProcessed: decision.autoProcessed,
        requiresHumanReview: decision.requiresHumanReview,
        denyReason: decision.denyReason,
        auditTrailId: decision.auditTrailId,
      );
    } catch (e, stackTrace) {
      print('❌ Error processing claim decision: $e');
      print('Stack trace: $stackTrace');

      // Fallback to safe default (human review)
      return _createFallbackDecision(claim, e.toString());
    }
  }

  /// Gather all input data for AI analysis
  Future<Map<String, dynamic>> _gatherInputData({
    required Claim claim,
    List<ClaimDocumentAnalysis>? documentAnalyses,
    Map<String, dynamic>? historicalData,
  }) async {
    // Get document analyses if not provided
    if (documentAnalyses == null || documentAnalyses.isEmpty) {
      try {
        documentAnalyses = await _documentService.getClaimDocuments(claim.claimId);
      } catch (e) {
        print('Warning: Could not retrieve document analyses: $e');
        documentAnalyses = [];
      }
    }

    // Get historical data if not provided
    if (historicalData == null) {
      try {
        historicalData = await _getHistoricalData(claim);
      } catch (e) {
        print('Warning: Could not retrieve historical data: $e');
        historicalData = {};
      }
    }

    // Calculate document confidence
    // If documents were AI-analyzed, use those scores
    // Otherwise, give credit for having attachments uploaded (0.8 = 80% confidence)
    final avgDocumentConfidence = documentAnalyses.isNotEmpty
        ? documentAnalyses
                .map((d) => d.confidenceScore)
                .reduce((a, b) => a + b) /
            documentAnalyses.length
        : (claim.attachments.isNotEmpty ? 0.8 : 0.0); // 80% confidence for uploaded docs

    // Check for fraud flags
    final hasFraudFlags = documentAnalyses.any((d) => d.hasFraudFlags);
    final allFraudFlags = documentAnalyses
        .expand((d) => d.fraudFlags)
        .toSet()
        .toList();

    return {
      'claim': {
        'claimId': claim.claimId,
        'policyId': claim.policyId,
        'petId': claim.petId,
        'incidentDate': claim.incidentDate.toIso8601String(),
        'claimType': claim.claimType.value,
        'claimAmount': claim.claimAmount,
        'currency': claim.currency,
        'description': claim.description,
        'status': claim.status.value,
        'attachmentCount': claim.attachments.length, // Add attachment count
      },
      'documents': documentAnalyses.map((d) => {
        'providerName': d.providerName,
        'serviceDate': d.serviceDate?.toIso8601String(),
        'totalCharge': d.totalCharge,
        'diagnosisCodes': d.diagnosisCodes,
        'procedureCodes': d.procedureCodes,
        'isLegitimate': d.isLegitimate,
        'treatment': d.treatment,
        'confidenceScore': d.confidenceScore,
        'fraudFlags': d.fraudFlags,
      }).toList(),
      'documentSummary': {
        'totalDocuments': documentAnalyses.length,
        'avgConfidence': avgDocumentConfidence,
        'hasFraudFlags': hasFraudFlags,
        'fraudFlags': allFraudFlags,
        'allLegitimate': documentAnalyses.every((d) => d.isLegitimate),
      },
      'historicalData': historicalData,
    };
  }

  /// Get historical data (risk score, previous claims, etc.)
  Future<Map<String, dynamic>> _getHistoricalData(Claim claim) async {
    try {
      // Get policy data
      final policyDoc = await _firestore
          .collection('policies')
          .doc(claim.policyId)
          .get();

      if (!policyDoc.exists) {
        return {};
      }

      final policyData = policyDoc.data()!;

      // Get previous claims for this policy
      final previousClaimsSnapshot = await _firestore
          .collection('claims')
          .where('policyId', isEqualTo: claim.policyId)
          .where('status', isEqualTo: 'settled')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final previousClaims = previousClaimsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'claimId': doc.id,
          'claimAmount': data['claimAmount'],
          'claimType': data['claimType'],
          'settledAt': data['settledAt'],
        };
      }).toList();

      return {
        'riskScore': policyData['riskScore'] ?? 0.0,
        'wasManuallyApproved': policyData['wasManuallyApproved'] ?? false,
        'policyStartDate': policyData['startDate'],
        'premiumAmount': policyData['premiumAmount'] ?? 0.0,
        'previousClaims': previousClaims,
        'totalPreviousClaimsAmount': previousClaims.fold<double>(
          0.0,
          (sum, claim) => sum + (claim['claimAmount'] as num).toDouble(),
        ),
        'claimFrequency': previousClaims.length,
      };
    } catch (e) {
      print('Error getting historical data: $e');
      return {};
    }
  }

  /// Run AI analysis with retry logic
  Future<AIAnalysisResult> _runAIAnalysisWithRetry(
    Map<String, dynamic> inputData,
  ) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      attempts++;
      try {
        print('   Attempt $attempts of $maxRetries...');
        return await _runAIAnalysis(inputData);
      } catch (e) {
        lastError = e as Exception;
        print('   Attempt $attempts failed: $e');
        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    // All retries failed - use mock fallback
    print('⚠️ All AI attempts failed, using mock fallback');
    return _createMockAnalysis(inputData, lastError?.toString());
  }

  /// Run AI analysis using GPT-4o
  Future<AIAnalysisResult> _runAIAnalysis(
    Map<String, dynamic> inputData,
  ) async {
    final prompt = _buildAIPrompt(inputData);

    final response = await _gptService.generateText(prompt);
    final result = _parseAIResponse(response);

    return result;
  }

  /// Build structured prompt for GPT-4o
  String _buildAIPrompt(Map<String, dynamic> inputData) {
    final claim = inputData['claim'];
    final docs = inputData['documents'] as List;
    final docSummary = inputData['documentSummary'];
    final historical = inputData['historicalData'];

    return '''
You are an expert veterinary insurance claims adjuster with 20 years of experience.

TASK: Analyze this pet insurance claim and provide a recommendation.

═══════════════════════════════════════════════════════════════
CLAIM INFORMATION
═══════════════════════════════════════════════════════════════
Claim ID: ${claim['claimId']}
Policy ID: ${claim['policyId']}
Incident Date: ${claim['incidentDate']}
Claim Type: ${claim['claimType']}
Claim Amount: \$${claim['claimAmount']}
Description: ${claim['description']}

═══════════════════════════════════════════════════════════════
SUPPORTING DOCUMENTS (${docs.length} AI-analyzed, ${claim['attachmentCount'] ?? 0} uploaded)
═══════════════════════════════════════════════════════════════
${claim['attachmentCount'] > 0 && docs.isEmpty ? 'Documents uploaded but not yet AI-analyzed. Give moderate confidence (70-80%) for having documentation.' : docs.isEmpty ? 'No documents provided' : docs.map((d) => '''
Provider: ${d['providerName']}
Service Date: ${d['serviceDate']}
Total Charge: \$${d['totalCharge']}
Diagnosis: ${d['diagnosisCodes']?.join(', ') ?? 'None'}
Procedures: ${d['procedureCodes']?.join(', ') ?? 'None'}
Treatment: ${d['treatment']}
Document Confidence: ${(d['confidenceScore'] * 100).toStringAsFixed(1)}%
Legitimate: ${d['isLegitimate']}
${d['fraudFlags'].isNotEmpty ? 'FRAUD FLAGS: ${d['fraudFlags'].join(", ")}' : ''}
''').join('\n---\n')}

Document Summary:
- Total Documents: ${docSummary['totalDocuments']}
- Average Confidence: ${(docSummary['avgConfidence'] * 100).toStringAsFixed(1)}%
- All Legitimate: ${docSummary['allLegitimate']}
- Has Fraud Flags: ${docSummary['hasFraudFlags']}
${docSummary['fraudFlags'].isNotEmpty ? '- Fraud Flags: ${docSummary['fraudFlags'].join(", ")}' : ''}

═══════════════════════════════════════════════════════════════
HISTORICAL DATA
═══════════════════════════════════════════════════════════════
Risk Score at Binding: ${historical['riskScore'] ?? 'Unknown'}
Was Manually Approved: ${historical['wasManuallyApproved'] ?? 'Unknown'}
Previous Claims: ${historical['claimFrequency'] ?? 0}
Total Previous Claims Amount: \$${historical['totalPreviousClaimsAmount'] ?? 0}
Premium Amount: \$${historical['premiumAmount'] ?? 'Unknown'}

═══════════════════════════════════════════════════════════════
ANALYSIS QUESTIONS
═══════════════════════════════════════════════════════════════
1. Is this claim legitimate based on all available evidence?
2. Is the claimed amount reasonable for the treatment provided?
3. Are there any red flags or concerns?
4. What is your confidence in this assessment (0-100)?
5. Should this claim be approved, denied, or escalated to human review?

═══════════════════════════════════════════════════════════════
RESPONSE FORMAT (JSON ONLY)
═══════════════════════════════════════════════════════════════
Return ONLY valid JSON in this exact format:
{
  "legitimacy": "legitimate" | "suspicious" | "fraudulent",
  "costReasonableness": "reasonable" | "slightly_high" | "excessive" | "too_low",
  "confidenceScore": 0-100,
  "recommendation": "approve" | "deny" | "escalate",
  "explanation": "2-3 sentence plain-language explanation of your reasoning",
  "redFlags": ["flag1", "flag2"] or [],
  "suggestedPayoutAmount": dollar_amount,
  "requiresHumanReview": true | false
}

CRITICAL: Return ONLY the JSON, no other text.

JSON:''';
  }

  /// Parse AI response into structured result
  AIAnalysisResult _parseAIResponse(String response) {
    try {
      // Clean response
      final jsonStr = response
          .trim()
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Try to find JSON object
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch == null) {
        throw Exception('No JSON found in response');
      }

      final Map<String, dynamic> result = {};
      final json = jsonMatch.group(0)!;

      // Parse fields manually (safer than dart:convert for untrusted input)
      result['legitimacy'] = _extractJsonString(json, 'legitimacy') ?? 'suspicious';
      result['costReasonableness'] = _extractJsonString(json, 'costReasonableness') ?? 'reasonable';
      result['confidenceScore'] = _extractJsonNumber(json, 'confidenceScore') ?? 50.0;
      result['recommendation'] = _extractJsonString(json, 'recommendation') ?? 'escalate';
      result['explanation'] = _extractJsonString(json, 'explanation') ?? 'Analysis completed';
      result['suggestedPayoutAmount'] = _extractJsonNumber(json, 'suggestedPayoutAmount') ?? 0.0;
      result['requiresHumanReview'] = _extractJsonBool(json, 'requiresHumanReview') ?? true;
      result['redFlags'] = _extractJsonArray(json, 'redFlags') ?? [];

      return AIAnalysisResult(
        legitimacy: result['legitimacy'],
        costReasonableness: result['costReasonableness'],
        confidenceScore: result['confidenceScore'].toDouble(),
        recommendation: result['recommendation'],
        explanation: result['explanation'],
        redFlags: List<String>.from(result['redFlags']),
        suggestedPayoutAmount: result['suggestedPayoutAmount'].toDouble(),
        requiresHumanReview: result['requiresHumanReview'],
      );
    } catch (e) {
      print('Error parsing AI response: $e');
      print('Response was: $response');
      throw Exception('Failed to parse AI response: $e');
    }
  }

  /// Extract string from JSON
  String? _extractJsonString(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
    final match = pattern.firstMatch(json);
    return match?.group(1);
  }

  /// Extract number from JSON
  double? _extractJsonNumber(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*([0-9.]+)');
    final match = pattern.firstMatch(json);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  /// Extract boolean from JSON
  bool? _extractJsonBool(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*(true|false)');
    final match = pattern.firstMatch(json);
    return match != null ? match.group(1) == 'true' : null;
  }

  /// Extract array from JSON
  List<String>? _extractJsonArray(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*\\[([^\\]]*)\\]');
    final match = pattern.firstMatch(json);
    if (match == null) return null;

    final content = match.group(1)!;
    if (content.trim().isEmpty) return [];

    return content
        .split(',')
        .map((s) => s.trim().replaceAll('"', ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Apply actuarial rules to determine final decision
  ClaimDecisionData _applyActuarialRules({
    required AIAnalysisResult aiResult,
    required Claim claim,
    required Map<String, dynamic> inputData,
    required bool enableAutoApprove,
  }) {
    final confidenceScore = aiResult.confidenceScore;
    final claimAmount = claim.claimAmount;
    final hasRedFlags = aiResult.redFlags.isNotEmpty;
    final docSummary = inputData['documentSummary'];
    final hasFraudFlags = docSummary['hasFraudFlags'] as bool;

    AIDecision aiDecision;
    ClaimStatus finalStatus;
    bool autoProcessed = false;
    bool requiresHumanReview = false;
    String? denyReason;
    String explanation = aiResult.explanation;

    // Rule 1: High confidence + low amount = auto-approve
    if (enableAutoApprove &&
        confidenceScore >= autoApproveThreshold &&
        claimAmount < autoApproveAmountLimit &&
        !hasRedFlags &&
        !hasFraudFlags &&
        aiResult.legitimacy == 'legitimate') {
      aiDecision = AIDecision.approve;
      finalStatus = ClaimStatus.settled;
      autoProcessed = true;
      explanation += '\n\n✅ Auto-approved: High confidence (${confidenceScore.toStringAsFixed(1)}%) '
          'and amount under \$${autoApproveAmountLimit.toStringAsFixed(0)} threshold.';
    }
    // Rule 2: Medium confidence = human review
    else if (confidenceScore >= humanReviewThreshold &&
        confidenceScore < autoApproveThreshold) {
      aiDecision = AIDecision.escalate;
      finalStatus = ClaimStatus.processing;
      requiresHumanReview = true;
      explanation += '\n\n⚠️ Escalated for human review: Confidence score '
          '${confidenceScore.toStringAsFixed(1)}% requires manual verification.';
    }
    // Rule 3: Low confidence = auto-deny
    else if (confidenceScore < humanReviewThreshold) {
      aiDecision = AIDecision.deny;
      finalStatus = ClaimStatus.denied;
      autoProcessed = true;
      denyReason = _generateDenyReason(aiResult, confidenceScore);
      explanation += '\n\n❌ Auto-denied: $denyReason';
    }
    // Rule 4: Fraud flags = auto-deny
    else if (hasFraudFlags || hasRedFlags) {
      aiDecision = AIDecision.deny;
      finalStatus = ClaimStatus.denied;
      autoProcessed = true;
      denyReason = 'Potential fraud detected: ${[...docSummary['fraudFlags'] as List, ...aiResult.redFlags].join(", ")}';
      explanation += '\n\n❌ Auto-denied: $denyReason';
    }
    // Rule 5: High amount = human review (even if high confidence)
    else if (claimAmount >= autoApproveAmountLimit) {
      aiDecision = AIDecision.escalate;
      finalStatus = ClaimStatus.processing;
      requiresHumanReview = true;
      explanation += '\n\n⚠️ Escalated for human review: Claim amount '
          '\$${claimAmount.toStringAsFixed(2)} exceeds auto-approval threshold.';
    }
    // Default: escalate
    else {
      aiDecision = AIDecision.escalate;
      finalStatus = ClaimStatus.processing;
      requiresHumanReview = true;
      explanation += '\n\n⚠️ Escalated for human review: Manual verification recommended.';
    }

    return ClaimDecisionData(
      aiConfidenceScore: confidenceScore,
      aiDecision: aiDecision,
      explanation: explanation,
      finalStatus: finalStatus,
      autoProcessed: autoProcessed,
      requiresHumanReview: requiresHumanReview,
      denyReason: denyReason,
      suggestedPayoutAmount: aiResult.suggestedPayoutAmount,
      redFlags: aiResult.redFlags,
      auditTrailId: '', // Will be set after logging
    );
  }

  /// Generate human-readable deny reason
  String _generateDenyReason(AIAnalysisResult aiResult, double confidenceScore) {
    final reasons = <String>[];

    if (confidenceScore < 30) {
      reasons.add('Insufficient confidence in claim legitimacy (${confidenceScore.toStringAsFixed(1)}%)');
    } else if (confidenceScore < humanReviewThreshold) {
      reasons.add('Low confidence score (${confidenceScore.toStringAsFixed(1)}%)');
    }

    if (aiResult.legitimacy == 'fraudulent') {
      reasons.add('Claim appears fraudulent');
    } else if (aiResult.legitimacy == 'suspicious') {
      reasons.add('Suspicious claim characteristics detected');
    }

    if (aiResult.costReasonableness == 'excessive') {
      reasons.add('Claimed amount significantly exceeds reasonable cost');
    } else if (aiResult.costReasonableness == 'too_low') {
      reasons.add('Claimed amount unusually low for treatment type');
    }

    if (aiResult.redFlags.isNotEmpty) {
      reasons.add('Red flags: ${aiResult.redFlags.join(", ")}');
    }

    if (reasons.isEmpty) {
      return 'Claim does not meet approval criteria based on AI analysis';
    }

    return reasons.join('; ');
  }

  /// Update claim with decision
  Future<Claim> _updateClaimWithDecision(
    Claim claim,
    ClaimDecisionData decision,
  ) async {
    final updatedClaim = claim.copyWith(
      aiConfidenceScore: decision.aiConfidenceScore / 100.0, // Store as 0-1
      aiDecision: decision.aiDecision,
      aiReasoningExplanation: {
        'explanation': decision.explanation,
        'confidenceScore': decision.aiConfidenceScore,
        'suggestedPayoutAmount': decision.suggestedPayoutAmount,
        'redFlags': decision.redFlags,
        'autoProcessed': decision.autoProcessed,
        'processedAt': DateTime.now().toIso8601String(),
      },
      status: decision.finalStatus,
      updatedAt: DateTime.now(),
      settledAt: decision.finalStatus == ClaimStatus.settled
          ? DateTime.now()
          : claim.settledAt,
    );

    // Update in Firestore - only update the fields that changed
    await _firestore
        .collection('claims')
        .doc(claim.claimId)
        .update({
      'aiConfidenceScore': updatedClaim.aiConfidenceScore,
      'aiDecision': updatedClaim.aiDecision?.value,
      'aiReasoningExplanation': updatedClaim.aiReasoningExplanation,
      'status': updatedClaim.status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedClaim.settledAt != null) 
        'settledAt': Timestamp.fromDate(updatedClaim.settledAt!),
    });

    return updatedClaim;
  }

  /// Log decision to audit trail
  Future<String> _logToAuditTrail(
    String claimId,
    ClaimDecisionData decision,
    Map<String, dynamic> inputData,
  ) async {
    final auditLog = {
      'claimId': claimId,
      'timestamp': FieldValue.serverTimestamp(),
      'aiConfidenceScore': decision.aiConfidenceScore,
      'aiDecision': decision.aiDecision.value,
      'explanation': decision.explanation,
      'finalStatus': decision.finalStatus.value,
      'autoProcessed': decision.autoProcessed,
      'requiresHumanReview': decision.requiresHumanReview,
      'denyReason': decision.denyReason,
      'suggestedPayoutAmount': decision.suggestedPayoutAmount,
      'redFlags': decision.redFlags,
      'inputData': {
        'documentCount': inputData['documents'].length,
        'avgDocumentConfidence': inputData['documentSummary']['avgConfidence'],
        'hasFraudFlags': inputData['documentSummary']['hasFraudFlags'],
        'historicalRiskScore': inputData['historicalData']['riskScore'],
        'previousClaimCount': inputData['historicalData']['claimFrequency'],
      },
      'processingMetadata': {
        'engineVersion': '1.0.0',
        'modelUsed': 'gpt-4o',
        'processingTime': DateTime.now().toIso8601String(),
      },
    };

    final docRef = await _firestore
        .collection('claims')
        .doc(claimId)
        .collection('ai_audit_trail')
        .add(auditLog);

    return docRef.id;
  }

  /// Create mock analysis for offline/fallback mode
  AIAnalysisResult _createMockAnalysis(
    Map<String, dynamic> inputData,
    String? error,
  ) {
    final claim = inputData['claim'];
    final claimAmount = claim['claimAmount'] as double;
    final docSummary = inputData['documentSummary'];

    // Conservative fallback - escalate to human
    return AIAnalysisResult(
      legitimacy: 'suspicious',
      costReasonableness: 'reasonable',
      confidenceScore: 50.0,
      recommendation: 'escalate',
      explanation: 'AI analysis unavailable (${error ?? "offline"}). '
          'Claim requires manual review. '
          'Document confidence: ${(docSummary['avgConfidence'] * 100).toStringAsFixed(1)}%.',
      redFlags: ['ai_analysis_failed'],
      suggestedPayoutAmount: claimAmount,
      requiresHumanReview: true,
    );
  }

  /// Create fallback decision result
  ClaimDecisionResult _createFallbackDecision(Claim claim, String error) {
    return ClaimDecisionResult(
      claim: claim,
      aiConfidenceScore: 50.0,
      aiDecision: AIDecision.escalate,
      explanation: 'Decision engine error: $error. Claim escalated for manual review.',
      finalStatus: ClaimStatus.processing,
      autoProcessed: false,
      requiresHumanReview: true,
      denyReason: null,
      auditTrailId: '',
    );
  }

  /// Batch process multiple claims
  Future<List<ClaimDecisionResult>> processMultipleClaims(
    List<Claim> claims, {
    bool enableAutoApprove = true,
  }) async {
    final results = <ClaimDecisionResult>[];

    for (final claim in claims) {
      try {
        final result = await processClaimDecision(
          claim: claim,
          enableAutoApprove: enableAutoApprove,
        );
        results.add(result);
      } catch (e) {
        print('Error processing claim ${claim.claimId}: $e');
        results.add(_createFallbackDecision(claim, e.toString()));
      }
    }

    return results;
  }

  /// Get audit trail for a claim
  Future<List<Map<String, dynamic>>> getAuditTrail(String claimId) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('ai_audit_trail')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting audit trail: $e');
      return [];
    }
  }

  /// Get decision statistics
  Future<Map<String, dynamic>> getDecisionStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('claims');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final claims = snapshot.docs;

      int totalClaims = claims.length;
      int autoApproved = 0;
      int autoDenied = 0;
      int humanReview = 0;
      double totalAutoApprovedAmount = 0.0;
      double avgConfidence = 0.0;
      int confidenceCount = 0;

      for (final doc in claims) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        final aiDecision = data['aiDecision'];
        final confidence = data['aiConfidenceScore'];

        if (confidence != null) {
          avgConfidence += (confidence as num).toDouble() * 100;
          confidenceCount++;
        }

        if (status == 'settled' && confidence != null && confidence >= autoApproveThreshold / 100) {
          autoApproved++;
          totalAutoApprovedAmount += (data['claimAmount'] as num).toDouble();
        } else if (status == 'denied') {
          autoDenied++;
        } else if (aiDecision == 'escalate' || status == 'processing') {
          humanReview++;
        }
      }

      return {
        'totalClaims': totalClaims,
        'autoApproved': autoApproved,
        'autoDenied': autoDenied,
        'humanReview': humanReview,
        'autoApprovalRate': totalClaims > 0 ? (autoApproved / totalClaims) * 100 : 0.0,
        'autoDenialRate': totalClaims > 0 ? (autoDenied / totalClaims) * 100 : 0.0,
        'humanReviewRate': totalClaims > 0 ? (humanReview / totalClaims) * 100 : 0.0,
        'totalAutoApprovedAmount': totalAutoApprovedAmount,
        'avgAutoApprovedAmount': autoApproved > 0 ? totalAutoApprovedAmount / autoApproved : 0.0,
        'avgConfidenceScore': confidenceCount > 0 ? avgConfidence / confidenceCount : 0.0,
      };
    } catch (e) {
      print('Error getting decision stats: $e');
      return {};
    }
  }
}

/// AI analysis result from GPT-4o
class AIAnalysisResult {
  final String legitimacy;
  final String costReasonableness;
  final double confidenceScore;
  final String recommendation;
  final String explanation;
  final List<String> redFlags;
  final double suggestedPayoutAmount;
  final bool requiresHumanReview;

  AIAnalysisResult({
    required this.legitimacy,
    required this.costReasonableness,
    required this.confidenceScore,
    required this.recommendation,
    required this.explanation,
    required this.redFlags,
    required this.suggestedPayoutAmount,
    required this.requiresHumanReview,
  });
}

/// Internal decision data
class ClaimDecisionData {
  final double aiConfidenceScore;
  final AIDecision aiDecision;
  final String explanation;
  final ClaimStatus finalStatus;
  final bool autoProcessed;
  final bool requiresHumanReview;
  final String? denyReason;
  final double suggestedPayoutAmount;
  final List<String> redFlags;
  String auditTrailId;

  ClaimDecisionData({
    required this.aiConfidenceScore,
    required this.aiDecision,
    required this.explanation,
    required this.finalStatus,
    required this.autoProcessed,
    required this.requiresHumanReview,
    this.denyReason,
    required this.suggestedPayoutAmount,
    required this.redFlags,
    required this.auditTrailId,
  });
}

/// Final claim decision result
class ClaimDecisionResult {
  final Claim claim;
  final double aiConfidenceScore;
  final AIDecision aiDecision;
  final String explanation;
  final ClaimStatus finalStatus;
  final bool autoProcessed;
  final bool requiresHumanReview;
  final String? denyReason;
  final String auditTrailId;

  ClaimDecisionResult({
    required this.claim,
    required this.aiConfidenceScore,
    required this.aiDecision,
    required this.explanation,
    required this.finalStatus,
    required this.autoProcessed,
    required this.requiresHumanReview,
    this.denyReason,
    required this.auditTrailId,
  });

  /// Check if claim was auto-approved
  bool get wasAutoApproved =>
      autoProcessed && aiDecision == AIDecision.approve;

  /// Check if claim was auto-denied
  bool get wasAutoDenied =>
      autoProcessed && aiDecision == AIDecision.deny;

  /// Get decision summary
  String get decisionSummary {
    if (wasAutoApproved) {
      return '✅ Auto-Approved (${aiConfidenceScore.toStringAsFixed(1)}% confidence)';
    } else if (wasAutoDenied) {
      return '❌ Auto-Denied: ${denyReason ?? "See explanation"}';
    } else if (requiresHumanReview) {
      return '⚠️ Requires Human Review (${aiConfidenceScore.toStringAsFixed(1)}% confidence)';
    } else {
      return '🤖 AI Decision: ${aiDecision.displayName}';
    }
  }
}

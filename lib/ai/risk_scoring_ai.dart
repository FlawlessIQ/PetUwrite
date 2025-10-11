import 'ai_service.dart';
import '../models/pet.dart';
import '../models/risk_score.dart';
import '../services/vet_history_parser.dart';

/// AI-powered risk scoring analyzer
class RiskScoringAI {
  final AIService _aiService;
  
  RiskScoringAI({required AIService aiService}) : _aiService = aiService;
  
  /// Generate AI analysis for risk score
  Future<String> generateRiskAnalysis({
    required Pet pet,
    required RiskScore riskScore,
    VetRecordData? vetHistory,
  }) async {
    final petData = {
      'name': pet.name,
      'species': pet.species,
      'breed': pet.breed,
      'age': pet.ageInYears,
      'weight': pet.weight,
      'preExistingConditions': pet.preExistingConditions,
    };
    
    final vetData = vetHistory?.toJson() ?? {};
    
    final scores = {
      'overall': riskScore.overallScore,
      'riskLevel': riskScore.riskLevel.toString(),
      'categories': riskScore.categoryScores,
    };
    
    return await _aiService.generateText(
      _buildRiskAnalysisPrompt(petData, vetData, scores),
    );
  }
  
  /// Predict potential health risks using AI
  Future<List<PredictedRisk>> predictHealthRisks({
    required Pet pet,
    VetRecordData? vetHistory,
  }) async {
    final prompt = '''
Based on the following pet information and veterinary history, predict potential health risks:

Pet: ${pet.breed} ${pet.species}, ${pet.ageInYears} years old
Weight: ${pet.weight}kg
Pre-existing: ${pet.preExistingConditions.join(', ')}
${vetHistory != null ? 'Vet History: ${vetHistory.toJson()}' : ''}

List the top 5 potential health risks with:
1. Condition name
2. Probability (low/medium/high)
3. Expected timeline
4. Typical cost range

Format as JSON array.
''';
    
    try {
      final response = await _aiService.generateText(prompt);
      final List<dynamic> risksData = _parseJsonArray(response);
      
      return risksData.map((data) => PredictedRisk.fromJson(data)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Generate personalized recommendations
  Future<List<String>> generateRecommendations({
    required Pet pet,
    required RiskScore riskScore,
  }) async {
    final prompt = '''
Given this pet's risk assessment, provide 5 actionable recommendations for the owner:

Pet: ${pet.name} (${pet.breed} ${pet.species})
Age: ${pet.ageInYears}
Risk Score: ${riskScore.overallScore}/100
Risk Level: ${riskScore.riskLevel}
Key Factors: ${riskScore.riskFactors.map((f) => f.description).join(', ')}

Provide recommendations for:
- Preventive care
- Lifestyle adjustments
- Coverage considerations
- Health monitoring
''';
    
    final response = await _aiService.generateText(prompt);
    return response
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .toList();
  }
  
  /// Compare breed-specific risks
  Future<BreedRiskComparison> compareBreedRisks(String breed) async {
    final prompt = '''
Provide a comprehensive risk analysis for the $breed breed:

1. Common health issues
2. Average lifespan
3. Typical vet costs
4. Insurance considerations
5. Preventive care recommendations

Return as JSON with keys: commonIssues, lifespan, costs, insuranceNotes, preventiveCare
''';
    
    try {
      final response = await _aiService.generateText(prompt);
      return BreedRiskComparison.fromJson(_parseJson(response));
    } catch (e) {
      return BreedRiskComparison(
        breed: breed,
        commonIssues: [],
        averageLifespan: 0,
        typicalCosts: 'Unknown',
        insuranceNotes: 'Data unavailable',
        preventiveCare: [],
      );
    }
  }
  
  String _buildRiskAnalysisPrompt(
    Map<String, dynamic> petData,
    Map<String, dynamic> vetData,
    Map<String, dynamic> scores,
  ) {
    return '''
Provide a comprehensive pet insurance risk analysis:

PET INFORMATION:
${_formatJson(petData)}

VETERINARY HISTORY:
${vetData.isNotEmpty ? _formatJson(vetData) : 'No history available'}

RISK ASSESSMENT:
${_formatJson(scores)}

Analyze and provide:
1. Overall risk assessment summary
2. Key contributing factors
3. Breed-specific considerations
4. Medical history impact
5. Coverage recommendations
6. Cost expectations
7. Long-term outlook

Keep the analysis professional, clear, and actionable.
''';
  }
  
  String _formatJson(Map<String, dynamic> data) {
    return data.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
  }
  
  Map<String, dynamic> _parseJson(String text) {
    // Try to extract JSON from text
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch != null) {
      return Map<String, dynamic>.from(
        // TODO: Implement proper JSON parsing
        {},
      );
    }
    return {};
  }
  
  List<dynamic> _parseJsonArray(String text) {
    // Try to extract JSON array from text
    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (jsonMatch != null) {
      return [];
    }
    return [];
  }
}

/// Predicted health risk
class PredictedRisk {
  final String condition;
  final String probability;
  final String timeline;
  final String costRange;
  
  PredictedRisk({
    required this.condition,
    required this.probability,
    required this.timeline,
    required this.costRange,
  });
  
  factory PredictedRisk.fromJson(Map<String, dynamic> json) {
    return PredictedRisk(
      condition: json['condition'] as String? ?? '',
      probability: json['probability'] as String? ?? '',
      timeline: json['timeline'] as String? ?? '',
      costRange: json['costRange'] as String? ?? '',
    );
  }
}

/// Breed risk comparison data
class BreedRiskComparison {
  final String breed;
  final List<String> commonIssues;
  final int averageLifespan;
  final String typicalCosts;
  final String insuranceNotes;
  final List<String> preventiveCare;
  
  BreedRiskComparison({
    required this.breed,
    required this.commonIssues,
    required this.averageLifespan,
    required this.typicalCosts,
    required this.insuranceNotes,
    required this.preventiveCare,
  });
  
  factory BreedRiskComparison.fromJson(Map<String, dynamic> json) {
    return BreedRiskComparison(
      breed: json['breed'] as String? ?? '',
      commonIssues: (json['commonIssues'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      averageLifespan: json['averageLifespan'] as int? ?? 0,
      typicalCosts: json['typicalCosts'] as String? ?? '',
      insuranceNotes: json['insuranceNotes'] as String? ?? '',
      preventiveCare: (json['preventiveCare'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

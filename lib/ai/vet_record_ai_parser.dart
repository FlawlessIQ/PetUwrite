import 'ai_service.dart';
import '../services/vet_history_parser.dart';

/// Service for parsing veterinary records using AI
class VetRecordAIParser {
  final AIService _aiService;
  
  VetRecordAIParser({required AIService aiService}) : _aiService = aiService;
  
  /// Parse veterinary record text using AI
  Future<VetRecordData> parseVetRecord(String text) async {
    try {
      final structuredData = await _aiService.parseStructuredData(text);
      return VetRecordData.fromJson(structuredData);
    } catch (e) {
      throw VetRecordParseException('AI parsing failed: $e');
    }
  }
  
  /// Extract medical insights from vet records
  Future<MedicalInsights> extractInsights(String text) async {
    final prompt = '''
Analyze the following veterinary records and extract key medical insights:

$text

Provide:
1. Chronic conditions identified
2. Recent health concerns
3. Vaccination status
4. Overall health assessment
5. Risk factors for insurance
''';
    
    final analysis = await _aiService.generateText(prompt);
    
    return MedicalInsights(
      analysis: analysis,
      chronicConditions: await _extractChronicConditions(text),
      healthStatus: await _assessHealthStatus(text),
    );
  }
  
  Future<List<String>> _extractChronicConditions(String text) async {
    final prompt = '''
From the following veterinary record, list ONLY chronic or recurring conditions (one per line):

$text
''';
    
    final response = await _aiService.generateText(prompt);
    return response
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .toList();
  }
  
  Future<String> _assessHealthStatus(String text) async {
    final prompt = '''
Based on this veterinary record, provide a one-sentence overall health assessment:

$text
''';
    
    return await _aiService.generateText(prompt);
  }
}

class MedicalInsights {
  final String analysis;
  final List<String> chronicConditions;
  final String healthStatus;
  
  MedicalInsights({
    required this.analysis,
    required this.chronicConditions,
    required this.healthStatus,
  });
}

class VetRecordParseException implements Exception {
  final String message;
  VetRecordParseException(this.message);
  
  @override
  String toString() => 'VetRecordParseException: $message';
}

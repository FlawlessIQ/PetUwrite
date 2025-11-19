import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http; // Still needed for VertexAIService

/// Interface for AI API integrations
abstract class AIService {
  Future<String> generateText(String prompt, {Map<String, dynamic>? options});
  Future<Map<String, dynamic>> parseStructuredData(String text);
}

/// OpenAI GPT API implementation using Firebase Cloud Functions
class GPTService implements AIService {
  final String apiKey; // No longer used, kept for compatibility
  final String model;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  GPTService({
    String? apiKey,
    this.model = 'gpt-4',
  }) : apiKey = apiKey ?? '' {
    // API key no longer required since we use Cloud Functions
    print('✅ GPTService initialized with Cloud Functions proxy');
  }
  
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    try {
      // Call Firebase Cloud Function instead of OpenAI directly
      final callable = _functions.httpsCallable('chatCompletion');
      
      final result = await callable.call({
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'model': model,
        'temperature': options?['temperature'] ?? 0.7,
        'maxTokens': options?['max_tokens'] ?? 500,
      });
      
      return result.data['content'] as String;
    } catch (e) {
      throw AIServiceException(
        'Cloud Function chatCompletion failed: $e',
      );
    }
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    final prompt = '''
Extract structured data from the following veterinary record text.
Return a JSON object with the following structure:
{
  "vaccinations": [{"name": "", "date": "", "expiryDate": ""}],
  "treatments": [{"diagnosis": "", "date": "", "treatment": "", "notes": ""}],
  "medications": [{"name": "", "dosage": "", "startDate": "", "endDate": ""}],
  "allergies": [],
  "surgeries": [{"procedure": "", "date": "", "complications": ""}],
  "lastCheckup": ""
}

Text:
$text
''';
    
    final response = await generateText(prompt, options: {
      'response_format': {'type': 'json_object'},
    });
    
    return jsonDecode(response);
  }
  
  /// Parse veterinary records using GPT
  Future<Map<String, dynamic>> parseVetRecords(String text) async {
    return await parseStructuredData(text);
  }
  
  /// Generate risk analysis using GPT
  Future<String> generateRiskAnalysis({
    required Map<String, dynamic> petData,
    required Map<String, dynamic> vetHistory,
    required Map<String, double> riskScores,
  }) async {
    final prompt = '''
Analyze the following pet insurance risk assessment data and provide a comprehensive analysis:

Pet Information:
${jsonEncode(petData)}

Veterinary History:
${jsonEncode(vetHistory)}

Risk Scores:
${jsonEncode(riskScores)}

Provide a detailed risk analysis including:
1. Key risk factors
2. Health trends
3. Recommendations for coverage
4. Potential concerns
''';
    
    return await generateText(prompt);
  }
}

/// Google Vertex AI implementation
class VertexAIService implements AIService {
  final String projectId;
  final String location;
  final String apiKey;
  final String model;
  
  VertexAIService({
    required this.projectId,
    required this.location,
    required this.apiKey,
    this.model = 'gemini-pro',
  });
  
  String get baseUrl => 
      'https://$location-aiplatform.googleapis.com/v1/projects/$projectId/locations/$location/publishers/google/models/$model:generateContent';
  
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        ...?options,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw AIServiceException(
        'Vertex AI request failed: ${response.statusCode} - ${response.body}',
      );
    }
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    final prompt = '''
Extract structured data from the following veterinary record text.
Return ONLY a valid JSON object (no markdown, no explanation) with this structure:
{
  "vaccinations": [{"name": "", "date": "", "expiryDate": ""}],
  "treatments": [{"diagnosis": "", "date": "", "treatment": "", "notes": ""}],
  "medications": [{"name": "", "dosage": "", "startDate": "", "endDate": ""}],
  "allergies": [],
  "surgeries": [{"procedure": "", "date": "", "complications": ""}],
  "lastCheckup": ""
}

Text:
$text
''';
    
    final response = await generateText(prompt);
    
    // Clean response (remove markdown code blocks if present)
    String cleanedResponse = response.trim();
    if (cleanedResponse.startsWith('```')) {
      cleanedResponse = cleanedResponse
          .replaceFirst(RegExp(r'^```json\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '');
    }
    
    return jsonDecode(cleanedResponse);
  }
  
  /// Parse veterinary records using Vertex AI
  Future<Map<String, dynamic>> parseVetRecords(String text) async {
    return await parseStructuredData(text);
  }
  
  /// Generate risk analysis using Vertex AI
  Future<String> generateRiskAnalysis({
    required Map<String, dynamic> petData,
    required Map<String, dynamic> vetHistory,
    required Map<String, double> riskScores,
  }) async {
    final prompt = '''
Analyze this pet insurance risk assessment:

Pet: ${jsonEncode(petData)}
History: ${jsonEncode(vetHistory)}
Scores: ${jsonEncode(riskScores)}

Provide analysis covering:
1. Key risk factors
2. Health trends
3. Coverage recommendations
4. Concerns to monitor
''';
    
    return await generateText(prompt);
  }
}

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  
  @override
  String toString() => 'AIServiceException: $message';
}

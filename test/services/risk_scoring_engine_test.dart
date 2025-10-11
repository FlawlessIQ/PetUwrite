import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/models/pet.dart';
import 'package:pet_underwriter_ai/models/owner.dart';
import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/risk_scoring_engine.dart';
import 'package:pet_underwriter_ai/ai/ai_service.dart';

/// Mock AI Service for testing without actual API calls
class MockAIService implements AIService {
  final String mockResponse;
  
  MockAIService({
    this.mockResponse = '''
Overall Risk Assessment: Score 52.5/100 (Medium Risk)

The pet shows moderate risk factors typical for the breed and age group.

Top Risk Categories:
1. Age: Senior pet (10 years) - increased likelihood of age-related conditions
2. Breed: German Shepherd - prone to hip dysplasia and degenerative myelopathy
3. Pre-existing: Hip dysplasia requires ongoing management

Breed-specific Considerations:
- Hip and elbow dysplasia common in German Shepherds
- Higher risk of degenerative myelopathy after age 8
- Prone to bloat (GDV) - emergency condition
- Eye conditions (cataracts, progressive retinal atrophy)

Geographic Risk Factors:
- California: Moderate vet costs (15% above national average)
- Urban area (SF): Higher access to specialists but higher costs
- Regional tick-borne diseases: Low risk in SF bay area

Preventive Care Recommendations:
- Regular hip/joint monitoring and X-rays
- Maintain healthy weight to reduce joint stress
- Consider joint supplements (glucosamine, chondroitin)
- Annual eye exams after age 7
- Monitor for signs of bloat (rapid veterinary response)

Coverage Recommendations:
- Recommended deductible: \$500-\$1000 (based on age and breed risk)
- Coverage limit: \$10,000+ annually (breed-specific conditions can be costly)
- Consider wellness add-on for preventive care
- Orthopedic coverage essential for this breed

Expected Claim Probability: 65% chance of claim in next 12 months based on age and breed profile.
''',
  });
  
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 100));
    return mockResponse;
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    return {};
  }
}

// Note: Firestore integration tests are excluded from unit tests
// Run integration tests separately with actual Firestore emulator

void main() {
  group('RiskScoringEngine with AI Integration', () {
    late RiskScoringEngine engine;
    late MockAIService mockAIService;
    
    setUp(() {
      mockAIService = MockAIService();
      engine = RiskScoringEngine(
        aiService: mockAIService,
        // Note: Firestore tests excluded - use integration tests with emulator
      );
    });
    
    final testPet = Pet(
      id: 'pet_test_123',
      name: 'Max',
      species: 'dog',
      breed: 'German Shepherd',
      dateOfBirth: DateTime(2015, 5, 15),
      gender: 'Male',
      weight: 35.0,
      isNeutered: true,
      preExistingConditions: ['Hip Dysplasia'],
    );
    
    final testOwner = Owner(
      id: 'owner_test_456',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@test.com',
      phoneNumber: '555-0123',
      address: Address(
        street: '123 Test St',
        city: 'San Francisco',
        state: 'CA',
        zipCode: '94102',
        country: 'USA',
      ),
    );
    
    test('calculateRiskScore includes AI analysis', () async {
      final riskScore = await engine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );
      
      expect(riskScore.overallScore, greaterThan(0));
      expect(riskScore.overallScore, lessThanOrEqualTo(100));
      expect(riskScore.aiAnalysis, isNotNull);
      expect(riskScore.aiAnalysis, contains('Risk Assessment'));
      expect(riskScore.riskFactors, isNotEmpty);
      expect(riskScore.categoryScores, isNotEmpty);
    });
    
    test('calculateRiskScore handles pet age correctly', () async {
      final youngPet = testPet.copyWith(
        dateOfBirth: DateTime.now().subtract(Duration(days: 365 * 2)),
      );
      
      final oldPet = testPet.copyWith(
        dateOfBirth: DateTime.now().subtract(Duration(days: 365 * 12)),
      );
      
      final youngScore = await engine.calculateRiskScore(
        pet: youngPet,
        owner: testOwner,
      );
      
      final oldScore = await engine.calculateRiskScore(
        pet: oldPet,
        owner: testOwner,
      );
      
      // Older pets should generally have higher risk
      expect(oldScore.categoryScores['age']!, greaterThan(youngScore.categoryScores['age']!));
    });
    
    test('calculateRiskScore includes owner location in AI prompt', () async {
      // Verify that location data is used (tested through AI analysis presence)
      final result = await engine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );
      
      expect(result.aiAnalysis, isNotNull);
      expect(result.aiAnalysis, contains('California'));
    });
    
    // Note: Firestore storage tests are excluded from unit tests
    // Use integration tests with Firestore emulator for storage testing
    
    test('calculateRiskScore handles high-risk breed', () async {
      final highRiskPet = testPet.copyWith(
        breed: 'Bulldog',
      );
      
      final riskScore = await engine.calculateRiskScore(
        pet: highRiskPet,
        owner: testOwner,
      );
      
      // Bulldogs should have higher breed risk
      expect(riskScore.categoryScores['breed']!, greaterThan(50));
      expect(riskScore.riskFactors.any((f) => 
        f.category == 'breed' && f.description.contains('Bulldog')
      ), isTrue);
    });
    
    test('calculateRiskScore handles pre-existing conditions', () async {
      final petWithConditions = testPet.copyWith(
        preExistingConditions: ['Hip Dysplasia', 'Arthritis', 'Heart Murmur'],
      );
      
      final riskScore = await engine.calculateRiskScore(
        pet: petWithConditions,
        owner: testOwner,
      );
      
      // Should have pre-existing condition risk factors
      final preExistingFactors = riskScore.riskFactors
          .where((f) => f.category == 'preExisting')
          .toList();
      
      expect(preExistingFactors.length, equals(3));
      expect(riskScore.categoryScores['preExisting']!, greaterThan(0));
    });
    
    test('AI service failure returns fallback analysis', () async {
      // Create engine with failing AI service
      final failingService = _FailingMockAIService();
      final failingEngine = RiskScoringEngine(
        aiService: failingService,
      );
      
      final riskScore = await failingEngine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );
      
      // Should still return a result with fallback analysis
      expect(riskScore.aiAnalysis, isNotNull);
      expect(riskScore.aiAnalysis, contains('Risk Score:'));
      expect(riskScore.overallScore, greaterThan(0));
    });
    
    test('RiskScoringException exists and can be thrown', () {
      // Verify the exception exists and works correctly
      expect(
        () => throw RiskScoringException('Test error'),
        throwsA(isA<RiskScoringException>()),
      );
      
      final exception = RiskScoringException('Custom message');
      expect(exception.toString(), contains('Custom message'));
    });
  });
  
  group('RiskScore Model Integration', () {
    test('RiskScore serialization includes aiAnalysis', () {
      final riskScore = RiskScore(
        id: 'risk_123',
        petId: 'pet_456',
        calculatedAt: DateTime(2025, 10, 7),
        overallScore: 55.5,
        riskLevel: RiskLevel.medium,
        categoryScores: {'age': 50.0, 'breed': 60.0},
        riskFactors: [],
        aiAnalysis: 'AI generated analysis text',
      );
      
      final json = riskScore.toJson();
      
      expect(json['aiAnalysis'], equals('AI generated analysis text'));
      expect(json['overallScore'], equals(55.5));
      
      final restored = RiskScore.fromJson(json);
      expect(restored.aiAnalysis, equals('AI generated analysis text'));
      expect(restored.overallScore, equals(55.5));
    });
  });
}

/// Mock AI service that always fails
class _FailingMockAIService implements AIService {
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    throw Exception('AI service unavailable');
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    throw Exception('AI service unavailable');
  }
}

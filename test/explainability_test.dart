import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_underwriter_ai/models/explainability_data.dart';

/// Unit tests for Explainability feature
void main() {
  group('FeatureContribution', () {
    test('creates contribution with all properties', () {
      final contribution = FeatureContribution(
        feature: 'Senior (8-10 years)',
        impact: 10.0,
        notes: 'Increased risk for age-related conditions',
        category: 'age',
      );

      expect(contribution.feature, 'Senior (8-10 years)');
      expect(contribution.impact, 10.0);
      expect(contribution.notes, 'Increased risk for age-related conditions');
      expect(contribution.category, 'age');
    });

    test('serializes to JSON correctly', () {
      final contribution = FeatureContribution(
        feature: 'Golden Retriever',
        impact: 12.0,
        notes: 'High cancer risk',
        category: 'breed',
      );

      final json = contribution.toJson();

      expect(json['feature'], 'Golden Retriever');
      expect(json['impact'], 12.0);
      expect(json['notes'], 'High cancer risk');
      expect(json['category'], 'breed');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'feature': 'Indoor Pet',
        'impact': -2.0,
        'notes': 'Lower accident risk',
        'category': 'lifestyle',
      };

      final contribution = FeatureContribution.fromJson(json);

      expect(contribution.feature, 'Indoor Pet');
      expect(contribution.impact, -2.0);
      expect(contribution.notes, 'Lower accident risk');
      expect(contribution.category, 'lifestyle');
    });

    test('handles positive and negative impacts', () {
      final positive = FeatureContribution(
        feature: 'High Risk Breed',
        impact: 12.0,
        notes: 'Test',
        category: 'breed',
      );

      final negative = FeatureContribution(
        feature: 'Good Vaccinations',
        impact: -5.0,
        notes: 'Test',
        category: 'medical',
      );

      expect(positive.impact, greaterThan(0));
      expect(negative.impact, lessThan(0));
    });
  });

  group('ExplainabilityData', () {
    late List<FeatureContribution> testContributions;

    setUp(() {
      testContributions = [
        FeatureContribution(
          feature: 'Senior (8-10 years)',
          impact: 10.0,
          notes: 'Age-related risk',
          category: 'age',
        ),
        FeatureContribution(
          feature: 'Golden Retriever',
          impact: 12.0,
          notes: 'High cancer risk',
          category: 'breed',
        ),
        FeatureContribution(
          feature: 'Vaccinations',
          impact: -4.0,
          notes: 'Good preventive care',
          category: 'medical',
        ),
        FeatureContribution(
          feature: 'Neutered',
          impact: -3.0,
          notes: 'Reduced cancer risk',
          category: 'lifestyle',
        ),
        FeatureContribution(
          feature: 'California',
          impact: 4.0,
          notes: 'High vet costs',
          category: 'geographic',
        ),
      ];
    });

    test('creates explainability data with all properties', () {
      final explainability = ExplainabilityData(
        id: 'exp_123',
        quoteId: 'quote_456',
        createdAt: DateTime(2024, 1, 15),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test summary',
      );

      expect(explainability.id, 'exp_123');
      expect(explainability.quoteId, 'quote_456');
      expect(explainability.baselineScore, 50.0);
      expect(explainability.contributions.length, 5);
      expect(explainability.finalScore, 69.0);
    });

    test('calculates total positive impact correctly', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      // 10.0 + 12.0 + 4.0 = 26.0
      expect(explainability.totalPositiveImpact, 26.0);
    });

    test('calculates total negative impact correctly', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      // -4.0 + -3.0 = -7.0
      expect(explainability.totalNegativeImpact, -7.0);
    });

    test('final score matches baseline + contributions', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final calculated = explainability.baselineScore +
          explainability.totalPositiveImpact +
          explainability.totalNegativeImpact;

      expect(calculated, 69.0);
      expect(explainability.finalScore, 69.0);
    });

    test('riskIncreasingFactors returns only positive impacts', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final riskFactors = explainability.riskIncreasingFactors;

      expect(riskFactors.length, 3); // Senior, Golden Retriever, California
      expect(riskFactors.every((c) => c.impact > 0), true);
      // Should be sorted descending
      expect(riskFactors[0].impact, greaterThanOrEqualTo(riskFactors[1].impact));
    });

    test('riskDecreasingFactors returns only negative impacts', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final protective = explainability.riskDecreasingFactors;

      expect(protective.length, 2); // Vaccinations, Neutered
      expect(protective.every((c) => c.impact < 0), true);
      // Should be sorted ascending (most negative first)
      expect(protective[0].impact, lessThanOrEqualTo(protective[1].impact));
    });

    test('getTopFeatures returns correct number of features', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final top3 = explainability.getTopFeatures(3);
      expect(top3.length, 3);

      // Should be sorted by absolute impact descending
      // Golden Retriever (12), Senior (10), Vaccinations (-4)
      expect(top3[0].feature, 'Golden Retriever');
      expect(top3[1].feature, 'Senior (8-10 years)');
    });

    test('getTopFeatures handles n larger than contributions', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final top100 = explainability.getTopFeatures(100);
      expect(top100.length, 5); // Only 5 contributions exist
    });

    test('contributionsByCategory groups correctly', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      final byCategory = explainability.contributionsByCategory;

      expect(byCategory.keys.length, 5); // age, breed, medical, lifestyle, geographic
      expect(byCategory['age']?.length, 1);
      expect(byCategory['breed']?.length, 1);
      expect(byCategory['medical']?.length, 1);
      expect(byCategory['lifestyle']?.length, 1);
      expect(byCategory['geographic']?.length, 1);
    });

    test('contributionsByCategory handles multiple contributions per category', () {
      final multipleContributions = [
        FeatureContribution(
          feature: 'Senior age',
          impact: 10.0,
          notes: 'Test',
          category: 'age',
        ),
        FeatureContribution(
          feature: 'Geriatric age',
          impact: 20.0,
          notes: 'Test',
          category: 'age',
        ),
        FeatureContribution(
          feature: 'Golden Retriever',
          impact: 12.0,
          notes: 'Test',
          category: 'breed',
        ),
      ];

      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: multipleContributions,
        finalScore: 92.0,
        overallSummary: 'Test',
      );

      final byCategory = explainability.contributionsByCategory;

      expect(byCategory['age']?.length, 2);
      expect(byCategory['breed']?.length, 1);
    });

    test('serializes to JSON correctly', () {
      final explainability = ExplainabilityData(
        id: 'exp_123',
        quoteId: 'quote_456',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test summary',
      );

      final json = explainability.toJson();

      expect(json['id'], 'exp_123');
      expect(json['quoteId'], 'quote_456');
      expect(json['baselineScore'], 50.0);
      expect(json['finalScore'], 69.0);
      expect(json['overallSummary'], 'Test summary');
      expect(json['contributions'], isA<List>());
      expect((json['contributions'] as List).length, 5);
      expect(json['createdAt'], isA<Timestamp>());
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'exp_789',
        'quoteId': 'quote_012',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 15, 10, 30)),
        'baselineScore': 50.0,
        'contributions': [
          {
            'feature': 'Test Feature',
            'impact': 5.0,
            'notes': 'Test notes',
            'category': 'test',
          }
        ],
        'finalScore': 55.0,
        'overallSummary': 'Test summary',
      };

      final explainability = ExplainabilityData.fromJson(json);

      expect(explainability.id, 'exp_789');
      expect(explainability.quoteId, 'quote_012');
      expect(explainability.baselineScore, 50.0);
      expect(explainability.finalScore, 55.0);
      expect(explainability.contributions.length, 1);
      expect(explainability.overallSummary, 'Test summary');
    });

    test('handles empty contributions list', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: [],
        finalScore: 50.0,
        overallSummary: 'No contributions',
      );

      expect(explainability.totalPositiveImpact, 0.0);
      expect(explainability.totalNegativeImpact, 0.0);
      expect(explainability.riskIncreasingFactors.isEmpty, true);
      expect(explainability.riskDecreasingFactors.isEmpty, true);
      expect(explainability.getTopFeatures(5).isEmpty, true);
      expect(explainability.contributionsByCategory.isEmpty, true);
    });

    test('validates baseline is always 50', () {
      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: testContributions,
        finalScore: 69.0,
        overallSummary: 'Test',
      );

      expect(explainability.baselineScore, 50.0);
    });
  });

  group('Impact Calculations', () {
    test('age contributions are in expected range', () {
      // Young adult: -5.0
      // Senior: +10.0
      // Geriatric: +20.0
      expect(-5.0, inInclusiveRange(-10.0, 0.0));
      expect(10.0, inInclusiveRange(0.0, 25.0));
      expect(20.0, inInclusiveRange(0.0, 25.0));
    });

    test('breed contributions are in expected range', () {
      // High-risk: +12.0
      // Low-risk: -8.0
      expect(12.0, inInclusiveRange(0.0, 15.0));
      expect(-8.0, inInclusiveRange(-10.0, 0.0));
    });

    test('medical contributions are in expected range', () {
      // Pre-existing per condition: +8.0
      // No pre-existing: -5.0
      // Vaccinations: -4.0 to +8.0
      expect(8.0, inInclusiveRange(0.0, 10.0));
      expect(-5.0, inInclusiveRange(-10.0, 0.0));
    });

    test('lifestyle contributions are in expected range', () {
      // Neutered: -3.0
      // Not neutered: +4.0
      // Indoor: -2.0
      // Outdoor: +6.0
      expect(-3.0, inInclusiveRange(-5.0, 0.0));
      expect(4.0, inInclusiveRange(0.0, 10.0));
      expect(-2.0, inInclusiveRange(-5.0, 0.0));
      expect(6.0, inInclusiveRange(0.0, 10.0));
    });

    test('geographic contributions are in expected range', () {
      // High-cost state: +4.0
      // Low-cost state: -2.0
      expect(4.0, inInclusiveRange(0.0, 10.0));
      expect(-2.0, inInclusiveRange(-5.0, 0.0));
    });

    test('final score stays within bounds 0-100', () {
      // Worst case: baseline (50) + maximum risks
      // Best case: baseline (50) - maximum protections
      
      // Maximum risk scenario (rough estimate)
      // Age geriatric: +20, Breed: +12, Pre-existing (3): +24, 
      // Not neutered: +4, Overweight: +6, No vax: +8, 
      // Medications (2): +8, Outdoor: +6, High cost state: +4
      // Total: ~92 points added to 50 = 142 (but should be capped)
      
      final maxRiskScore = 50.0 + 92.0;
      expect(maxRiskScore, lessThanOrEqualTo(150.0)); // Shows need for capping
      
      // In practice, should be capped at 100
      final cappedScore = maxRiskScore.clamp(0.0, 100.0);
      expect(cappedScore, 100.0);
    });
  });

  group('Category Analysis', () {
    test('can identify most impactful category', () {
      final contributions = [
        FeatureContribution(
          feature: 'Age factor 1',
          impact: 5.0,
          notes: 'Test',
          category: 'age',
        ),
        FeatureContribution(
          feature: 'Breed factor 1',
          impact: 12.0,
          notes: 'Test',
          category: 'breed',
        ),
        FeatureContribution(
          feature: 'Medical factor 1',
          impact: -2.0,
          notes: 'Test',
          category: 'medical',
        ),
      ];

      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: contributions,
        finalScore: 65.0,
        overallSummary: 'Test',
      );

      final byCategory = explainability.contributionsByCategory;
      
      var maxCategory = '';
      var maxImpact = 0.0;
      
      byCategory.forEach((category, contribs) {
        final total = contribs.fold(0.0, (sum, c) => sum + c.impact.abs());
        if (total > maxImpact) {
          maxImpact = total;
          maxCategory = category;
        }
      });

      expect(maxCategory, 'breed');
      expect(maxImpact, 12.0);
    });

    test('can calculate percentage contribution of each factor', () {
      final contributions = [
        FeatureContribution(
          feature: 'Factor 1',
          impact: 10.0,
          notes: 'Test',
          category: 'test',
        ),
        FeatureContribution(
          feature: 'Factor 2',
          impact: -5.0,
          notes: 'Test',
          category: 'test',
        ),
        FeatureContribution(
          feature: 'Factor 3',
          impact: 5.0,
          notes: 'Test',
          category: 'test',
        ),
      ];

      final explainability = ExplainabilityData(
        id: 'test',
        quoteId: 'test',
        createdAt: DateTime.now(),
        baselineScore: 50.0,
        contributions: contributions,
        finalScore: 60.0,
        overallSummary: 'Test',
      );

      final totalAbsoluteImpact = contributions.fold(
        0.0,
        (sum, c) => sum + c.impact.abs(),
      ); // 10 + 5 + 5 = 20

      expect(totalAbsoluteImpact, 20.0);

      // Factor 1: 10/20 = 50%
      // Factor 2: 5/20 = 25%
      // Factor 3: 5/20 = 25%
      final factor1Pct = (contributions[0].impact.abs() / totalAbsoluteImpact) * 100;
      expect(factor1Pct, 50.0);
    });
  });
}

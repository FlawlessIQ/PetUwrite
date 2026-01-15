import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pet_underwriter_ai/services/underwriting_case_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  group('UnderwritingCaseService NEED_MORE_INFO attempts', () {
    test('incrementNeedMoreInfoAttempts increments and stores fields', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MockFirebaseAuth();

      // Seed a case doc.
      await firestore.collection('underwriting_cases').doc('c1').set({
        'userId': 'u1',
        'needMoreInfoAttempts': 0,
      });

      final service = UnderwritingCaseService(firestore: firestore, auth: auth);

      final next = await service.incrementNeedMoreInfoAttempts(
        caseId: 'c1',
        reason: 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS',
        requiredEvidenceCodes: const ['RECENT_VET_RECORD', 'DIAGNOSTIC_RESULTS'],
      );

      expect(next, 1);

      final doc =
          await firestore.collection('underwriting_cases').doc('c1').get();
      final data = doc.data()!;
      expect(data['needMoreInfoAttempts'], 1);
      expect(data['lastNeedMoreInfoReason'], 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS');
      expect(
        (data['lastNeedMoreInfoEvidenceCodes'] as List).cast<String>(),
        ['RECENT_VET_RECORD', 'DIAGNOSTIC_RESULTS'],
      );
      // lastNeedMoreInfoAt is a timestamp server value; ensure field exists.
      expect(data.containsKey('lastNeedMoreInfoAt'), isTrue);
    });

    test('resetNeedMoreInfoAttempts clears attempt counter fields', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MockFirebaseAuth();

      await firestore.collection('underwriting_cases').doc('c2').set({
        'userId': 'u1',
        'needMoreInfoAttempts': 2,
        'lastNeedMoreInfoReason': 'SOME_REASON',
        'lastNeedMoreInfoEvidenceCodes': ['A'],
        'lastNeedMoreInfoAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final service = UnderwritingCaseService(firestore: firestore, auth: auth);

      await service.resetNeedMoreInfoAttempts(caseId: 'c2');

      final doc =
          await firestore.collection('underwriting_cases').doc('c2').get();
      final data = doc.data()!;
      expect(data['needMoreInfoAttempts'], 0);
      expect(data['lastNeedMoreInfoReason'], isNull);
      expect(
        (data['lastNeedMoreInfoEvidenceCodes'] as List).cast<String>(),
        isEmpty,
      );
      expect(data['lastNeedMoreInfoAt'], isNull);
    });
  });
}

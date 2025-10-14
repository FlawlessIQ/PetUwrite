import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/models/pet.dart';

void main() {
  group('Pet.fromJson Robustness Tests', () {
    test('should handle raw form data with petName and age', () {
      final formData = {
        'petName': 'Freddy',
        'species': 'dog',
        'breed': 'Labrador',
        'age': 3,
        'gender': 'male',
        'weight': 65.0,
        'neutered': true,
        'hasPreExistingConditions': false,
      };

      final pet = Pet.fromJson(formData);

      expect(pet.name, 'Freddy');
      expect(pet.species, 'dog');
      expect(pet.breed, 'Labrador');
      expect(pet.gender, 'male');
      expect(pet.weight, 65.0);
      expect(pet.isNeutered, true);
      // Age calculation may be off by 1 year depending on current date
      expect(pet.ageInYears, anyOf(equals(2), equals(3)));
    });

    test('should handle standard Pet JSON with dateOfBirth', () {
      final petJson = {
        'id': 'pet_123',
        'name': 'Max',
        'species': 'cat',
        'breed': 'Siamese',
        'dateOfBirth': '2020-01-15T00:00:00.000Z',
        'gender': 'female',
        'weight': 4.5,
        'isNeutered': false,
        'preExistingConditions': [],
      };

      final pet = Pet.fromJson(petJson);

      expect(pet.id, 'pet_123');
      expect(pet.name, 'Max');
      expect(pet.species, 'cat');
      expect(pet.breed, 'Siamese');
      expect(pet.gender, 'female');
      expect(pet.weight, 4.5);
      expect(pet.isNeutered, false);
    });

    test('should provide defaults for missing required fields', () {
      final minimalData = <String, dynamic>{};

      final pet = Pet.fromJson(minimalData);

      expect(pet.id, isNotEmpty);
      expect(pet.name, 'Unknown');
      expect(pet.species, 'dog');
      expect(pet.breed, 'Mixed Breed');
      expect(pet.gender, 'unknown');
      expect(pet.weight, 10.0);
      expect(pet.isNeutered, false);
    });

    test('should handle age as String', () {
      final formData = {
        'petName': 'Buddy',
        'species': 'dog',
        'breed': 'Golden Retriever',
        'age': '5',
        'gender': 'male',
        'weight': '70',
        'isNeutered': 'true',
      };

      final pet = Pet.fromJson(formData);

      expect(pet.name, 'Buddy');
      // Age calculation may be off by 1 year depending on current date
      expect(pet.ageInYears, anyOf(equals(4), equals(5)));
      expect(pet.weight, 70.0);
      expect(pet.isNeutered, true);
    });

    test('should handle both isNeutered and neutered fields', () {
      final data1 = {
        'name': 'Pet1',
        'isNeutered': true,
        'age': 2,
      };

      final data2 = {
        'petName': 'Pet2',
        'neutered': true,
        'age': 2,
      };

      final pet1 = Pet.fromJson(data1);
      final pet2 = Pet.fromJson(data2);

      expect(pet1.isNeutered, true);
      expect(pet2.isNeutered, true);
    });

    test('should convert age to dateOfBirth correctly', () {
      final formData = {
        'petName': 'Luna',
        'age': 2,
      };

      final pet = Pet.fromJson(formData);
      final now = DateTime.now();
      final expectedAge = now.year - pet.dateOfBirth.year;

      expect(expectedAge, closeTo(2, 1)); // Allow 1 year tolerance for date calculations
    });
  });
}

import 'package:flutter/foundation.dart';
import '../models/pet.dart';
import '../services/firebase_service.dart';

/// Provider for managing pet state
class PetProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  List<Pet> _pets = [];
  Pet? _selectedPet;
  bool _isLoading = false;
  String? _error;
  
  PetProvider({required FirebaseService firebaseService})
      : _firebaseService = firebaseService;
  
  List<Pet> get pets => _pets;
  Pet? get selectedPet => _selectedPet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> loadPets(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _firebaseService.getPetsByOwner(ownerId).listen((pets) {
        _pets = pets;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void selectPet(Pet pet) {
    _selectedPet = pet;
    notifyListeners();
  }
  
  Future<void> addPet(Pet pet) async {
    try {
      await _firebaseService.savePet(pet);
      _pets.add(pet);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> updatePet(Pet pet) async {
    try {
      await _firebaseService.updatePet(pet);
      final index = _pets.indexWhere((p) => p.id == pet.id);
      if (index != -1) {
        _pets[index] = pet;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> deletePet(String petId) async {
    try {
      await _firebaseService.deletePet(petId);
      _pets.removeWhere((p) => p.id == petId);
      if (_selectedPet?.id == petId) {
        _selectedPet = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

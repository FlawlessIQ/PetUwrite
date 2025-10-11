import 'package:flutter/foundation.dart';
import '../models/policy.dart';
import '../services/firebase_service.dart';

/// Provider for managing policy state
class PolicyProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  List<Policy> _policies = [];
  Policy? _selectedPolicy;
  bool _isLoading = false;
  String? _error;
  
  PolicyProvider({required FirebaseService firebaseService})
      : _firebaseService = firebaseService;
  
  List<Policy> get policies => _policies;
  Policy? get selectedPolicy => _selectedPolicy;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> loadPolicies(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _firebaseService.getPoliciesByOwner(ownerId).listen((policies) {
        _policies = policies;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void selectPolicy(Policy policy) {
    _selectedPolicy = policy;
    notifyListeners();
  }
  
  Future<void> createPolicy(Policy policy) async {
    try {
      await _firebaseService.savePolicy(policy);
      _policies.add(policy);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> updatePolicy(Policy policy) async {
    try {
      await _firebaseService.updatePolicy(policy);
      final index = _policies.indexWhere((p) => p.id == policy.id);
      if (index != -1) {
        _policies[index] = policy;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

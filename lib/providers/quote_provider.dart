import 'package:flutter/foundation.dart';

/// Provider for managing quote flow state
class QuoteProvider extends ChangeNotifier {
  Map<String, dynamic> _quoteData = {};
  int _currentStep = 0;
  
  Map<String, dynamic> get quoteData => _quoteData;
  int get currentStep => _currentStep;
  
  void updateQuoteData(String key, dynamic value) {
    _quoteData[key] = value;
    notifyListeners();
  }
  
  void updateMultiple(Map<String, dynamic> data) {
    _quoteData.addAll(data);
    notifyListeners();
  }
  
  void setCurrentStep(int step) {
    _currentStep = step;
    notifyListeners();
  }
  
  void nextStep() {
    _currentStep++;
    notifyListeners();
  }
  
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }
  
  void reset() {
    _quoteData = {};
    _currentStep = 0;
    notifyListeners();
  }
  
  bool validateStep(int step) {
    switch (step) {
      case 0: // Pet info
        return _quoteData['petName'] != null &&
               _quoteData['species'] != null &&
               _quoteData['breed'] != null;
      case 1: // Owner info
        return _quoteData['firstName'] != null &&
               _quoteData['lastName'] != null &&
               _quoteData['email'] != null;
      case 2: // Medical history
        return true; // Optional step
      default:
        return true;
    }
  }
}

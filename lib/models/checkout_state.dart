import 'package:flutter/foundation.dart';
import 'pet.dart';
import 'policy_exclusion.dart';
import '../services/quote_engine.dart';

/// Enumeration of checkout steps
enum CheckoutStep {
  review,
  ownerDetails,
  payment,
  confirmation,
}

/// Owner details for checkout
class OwnerDetails {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zipCode;
  final bool hasESignConsent;
  final DateTime? eSignConsentDate;

  OwnerDetails({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.zipCode,
    required this.hasESignConsent,
    this.eSignConsentDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'hasESignConsent': hasESignConsent,
      'eSignConsentDate': eSignConsentDate?.toIso8601String(),
    };
  }

  factory OwnerDetails.fromJson(Map<String, dynamic> json) {
    return OwnerDetails(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      addressLine1: json['addressLine1'] ?? '',
      addressLine2: json['addressLine2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
      hasESignConsent: json['hasESignConsent'] ?? false,
      eSignConsentDate: json['eSignConsentDate'] != null
          ? DateTime.parse(json['eSignConsentDate'])
          : null,
    );
  }

  String get fullName => '$firstName $lastName';

  String get fullAddress =>
      '$addressLine1${addressLine2.isNotEmpty ? ', $addressLine2' : ''}, $city, $state $zipCode';
}

/// Payment information
class PaymentInfo {
  final String? paymentIntentId;
  final String? paymentMethodId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final String? last4;
  final String? brand;
  final String? couponCode;
  final double? discountAmount;

  PaymentInfo({
    this.paymentIntentId,
    this.paymentMethodId,
    required this.amount,
    this.currency = 'usd',
    required this.status,
    this.paidAt,
    this.last4,
    this.brand,
    this.couponCode,
    this.discountAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'paymentIntentId': paymentIntentId,
      'paymentMethodId': paymentMethodId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paidAt': paidAt?.toIso8601String(),
      'last4': last4,
      'brand': brand,
      'couponCode': couponCode,
      'discountAmount': discountAmount,
    };
  }

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paymentIntentId: json['paymentIntentId'],
      paymentMethodId: json['paymentMethodId'],
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'usd',
      status: json['status'] ?? 'pending',
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      last4: json['last4'],
      brand: json['brand'],
      couponCode: json['couponCode'],
      discountAmount: json['discountAmount']?.toDouble(),
    );
  }
}

/// Policy document data
class PolicyDocument {
  final String policyId;
  final String policyNumber;
  final Pet pet;
  final OwnerDetails owner;
  final Plan plan;
  final PaymentInfo payment;
  final DateTime effectiveDate;
  final DateTime expirationDate;
  final DateTime createdAt;
  final String status;
  final String? underwritingCaseId;
  final List<PolicyExclusion> exclusions;
  final Map<String, dynamic>? underwritingSnapshot;

  PolicyDocument({
    required this.policyId,
    required this.policyNumber,
    required this.pet,
    required this.owner,
    required this.plan,
    required this.payment,
    required this.effectiveDate,
    required this.expirationDate,
    required this.createdAt,
    this.status = 'active',
    this.underwritingCaseId,
    this.exclusions = const [],
    this.underwritingSnapshot,
  });

  Map<String, dynamic> toJson() {
    return {
      'policyId': policyId,
      'policyNumber': policyNumber,
      'pet': pet.toJson(),
      'owner': owner.toJson(),
      'plan': plan.toJson(),
      'payment': payment.toJson(),
      'effectiveDate': effectiveDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'underwritingCaseId': underwritingCaseId,
      'exclusions': exclusions.map((e) => e.toJson()).toList(),
      'underwritingSnapshot': underwritingSnapshot,
    };
  }

  factory PolicyDocument.fromJson(Map<String, dynamic> json) {
    return PolicyDocument(
      policyId: json['policyId'] ?? '',
      policyNumber: json['policyNumber'] ?? '',
      pet: Pet.fromJson(json['pet']),
      owner: OwnerDetails.fromJson(json['owner']),
      plan: Plan.fromJson(json['plan']),
      payment: PaymentInfo.fromJson(json['payment']),
      effectiveDate: DateTime.parse(json['effectiveDate']),
      expirationDate: DateTime.parse(json['expirationDate']),
      createdAt: DateTime.parse(json['createdAt']),
      status: json['status'] ?? 'active',
      underwritingCaseId: json['underwritingCaseId']?.toString(),
      exclusions: (json['exclusions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(PolicyExclusion.fromJson)
              .toList() ??
          const [],
      underwritingSnapshot: (json['underwritingSnapshot'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// Checkout state provider
class CheckoutProvider extends ChangeNotifier {
  CheckoutStep _currentStep = CheckoutStep.review;
  Pet? _pet;
  Plan? _selectedPlan;
  OwnerDetails? _ownerDetails;
  PaymentInfo? _paymentInfo;
  PolicyDocument? _policy;
  bool _isProcessing = false;
  String? _error;

  // Underwriting metadata (Phase 5)
  String? _underwritingCaseId;
  List<PolicyExclusion> _exclusions = [];
  Map<String, dynamic>? _underwritingSnapshot;
  String _exclusionsKey = '';

  String _computeExclusionsKey(List<PolicyExclusion> exclusions) {
    final names = exclusions
        .map((e) => e.conditionName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join('|');
  }

  void _clearExclusionsAcknowledgements() {
    if (_underwritingSnapshot == null) return;
    final updated = Map<String, dynamic>.from(_underwritingSnapshot!);
    updated.remove('exclusionsAcknowledgements');
    updated.remove('exclusionsAcknowledgedAt');
    _underwritingSnapshot = updated;
  }

  // Getters
  CheckoutStep get currentStep => _currentStep;
  Pet? get pet => _pet;
  Plan? get selectedPlan => _selectedPlan;
  OwnerDetails? get ownerDetails => _ownerDetails;
  PaymentInfo? get paymentInfo => _paymentInfo;
  PolicyDocument? get policy => _policy;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  String? get underwritingCaseId => _underwritingCaseId;
  List<PolicyExclusion> get exclusions => _exclusions;
  Map<String, dynamic>? get underwritingSnapshot => _underwritingSnapshot;

  // Step progress
  int get currentStepIndex => _currentStep.index;
  int get totalSteps => CheckoutStep.values.length;
  double get progress => (currentStepIndex + 1) / totalSteps;

  // Validation
  bool get canProceedFromReview => _pet != null && _selectedPlan != null;
  bool get canProceedFromOwnerDetails =>
      _ownerDetails != null && _ownerDetails!.hasESignConsent;
  bool get canProceedFromPayment =>
      _paymentInfo != null && (_paymentInfo!.status == 'succeeded' || _paymentInfo!.status == 'test_waived');

  /// Initialize checkout with pet and plan
  void initialize({
    required Pet pet,
    required Plan plan,
  }) {
    _pet = pet;
    _selectedPlan = plan;
    _currentStep = CheckoutStep.review;
    _ownerDetails = null;
    _paymentInfo = null;
    _policy = null;
    _error = null;
    _exclusionsKey = _computeExclusionsKey(_exclusions);
    _clearExclusionsAcknowledgements();
    notifyListeners();
  }

  /// Set owner details
  void setOwnerDetails(OwnerDetails details) {
    _ownerDetails = details;
    _error = null;
    notifyListeners();
  }

  /// Set payment information
  void setPaymentInfo(PaymentInfo info) {
    _paymentInfo = info;
    _error = null;
    notifyListeners();
  }

  /// Set policy document
  void setPolicy(PolicyDocument policy) {
    _policy = policy;
    notifyListeners();
  }

  /// Set underwriting metadata (Phase 5)
  void setUnderwritingMetadata({
    String? caseId,
    List<PolicyExclusion>? exclusions,
    Map<String, dynamic>? snapshot,
  }) {
    if (caseId != null) _underwritingCaseId = caseId;

    if (exclusions != null) {
      final nextKey = _computeExclusionsKey(exclusions);
      if (nextKey != _exclusionsKey) {
        _exclusionsKey = nextKey;
        _clearExclusionsAcknowledgements();
      }
      _exclusions = exclusions;
    }

    if (snapshot != null) _underwritingSnapshot = snapshot;
    notifyListeners();
  }

  /// Records user acknowledgement that exclusions exist and will not be covered.
  /// Stored inside `underwritingSnapshot` so it is stamped onto the bound policy.
  void recordExclusionsAcknowledgement({required String source}) {
    final now = DateTime.now().toIso8601String();
    final updated = Map<String, dynamic>.from(_underwritingSnapshot ?? const {});

    final existing = (updated['exclusionsAcknowledgements'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final acknowledgements = Map<String, dynamic>.from(existing);
    acknowledgements[source] = now;

    updated['exclusionsAcknowledgements'] = acknowledgements;
    updated['exclusionsAcknowledgedAt'] = now;

    _underwritingSnapshot = updated;
    notifyListeners();
  }

  /// Set processing state
  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// Set error
  void setError(String? error) {
    _error = error;
    _isProcessing = false;
    notifyListeners();
  }

  /// Navigate to next step
  void nextStep() {
    if (_currentStep.index < CheckoutStep.values.length - 1) {
      switch (_currentStep) {
        case CheckoutStep.review:
          if (!canProceedFromReview) {
            _error = 'Please select a pet and plan';
            notifyListeners();
            return;
          }
          break;
        case CheckoutStep.ownerDetails:
          if (!canProceedFromOwnerDetails) {
            _error = 'Please complete owner details and accept e-sign consent';
            notifyListeners();
            return;
          }
          break;
        case CheckoutStep.payment:
          if (!canProceedFromPayment) {
            _error = 'Payment not completed';
            notifyListeners();
            return;
          }
          break;
        case CheckoutStep.confirmation:
          break;
      }

      _currentStep = CheckoutStep.values[_currentStep.index + 1];
      _error = null;
      notifyListeners();
    }
  }

  /// Navigate to previous step
  void previousStep() {
    if (_currentStep.index > 0) {
      _currentStep = CheckoutStep.values[_currentStep.index - 1];
      _error = null;
      notifyListeners();
    }
  }

  /// Jump to specific step
  void goToStep(CheckoutStep step) {
    _currentStep = step;
    _error = null;
    notifyListeners();
  }

  /// Reset checkout
  void reset() {
    _currentStep = CheckoutStep.review;
    _pet = null;
    _selectedPlan = null;
    _ownerDetails = null;
    _paymentInfo = null;
    _policy = null;
    _isProcessing = false;
    _error = null;
    notifyListeners();
  }

  /// Get step name
  String getStepName(CheckoutStep step) {
    switch (step) {
      case CheckoutStep.review:
        return 'Review';
      case CheckoutStep.ownerDetails:
        return 'Owner Details';
      case CheckoutStep.payment:
        return 'Payment';
      case CheckoutStep.confirmation:
        return 'Confirmation';
    }
  }

  /// Get step icon
  String getStepIcon(CheckoutStep step) {
    switch (step) {
      case CheckoutStep.review:
        return '📋';
      case CheckoutStep.ownerDetails:
        return '✍️';
      case CheckoutStep.payment:
        return '💳';
      case CheckoutStep.confirmation:
        return '✅';
    }
  }
}

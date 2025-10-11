import '../models/policy.dart';
import '../models/quote.dart';
import '../models/owner.dart';
import '../models/pet.dart';
import 'firebase_service.dart';
import 'payment_processor.dart';

/// Service for issuing insurance policies
class PolicyIssuance {
  final FirebaseService _firebaseService;
  final PaymentProcessor _paymentProcessor;
  
  PolicyIssuance({
    required FirebaseService firebaseService,
    required PaymentProcessor paymentProcessor,
  })  : _firebaseService = firebaseService,
        _paymentProcessor = paymentProcessor;
  
  /// Issue a new policy from an approved quote
  Future<PolicyIssuanceResult> issuePolicy({
    required Quote quote,
    required Owner owner,
    required Pet pet,
    required CoveragePlan selectedPlan,
    required PaymentMethod paymentMethod,
    required PaymentSchedule paymentSchedule,
  }) async {
    try {
      // Validate quote
      if (quote.isExpired) {
        return PolicyIssuanceResult(
          success: false,
          policy: null,
          errorMessage: 'Quote has expired',
        );
      }
      
      if (quote.status != QuoteStatus.approved) {
        return PolicyIssuanceResult(
          success: false,
          policy: null,
          errorMessage: 'Quote must be approved before issuing policy',
        );
      }
      
      // Process initial payment
      final paymentResult = await _paymentProcessor.processPayment(
        policyId: _generatePolicyId(),
        amount: _calculateInitialPayment(selectedPlan, paymentSchedule),
        paymentMethod: paymentMethod,
        schedule: paymentSchedule,
      );
      
      if (!paymentResult.success) {
        return PolicyIssuanceResult(
          success: false,
          policy: null,
          errorMessage: 'Payment failed: ${paymentResult.errorMessage}',
        );
      }
      
      // Create policy
      final policy = await _createPolicy(
        quote: quote,
        owner: owner,
        pet: pet,
        selectedPlan: selectedPlan,
        paymentSchedule: paymentSchedule,
      );
      
      // Setup recurring payment
      final recurringResult = await _paymentProcessor.setupRecurringPayment(
        policyId: policy.id,
        plan: selectedPlan,
        paymentMethod: paymentMethod,
        schedule: paymentSchedule,
      );
      
      if (!recurringResult.success) {
        // Policy created but recurring payment failed
        // Mark policy as needs attention
        return PolicyIssuanceResult(
          success: true,
          policy: policy,
          errorMessage: 'Policy created but recurring payment setup failed',
        );
      }
      
      // Save policy to database
      await _firebaseService.savePolicy(policy);
      
      // Send confirmation email
      await _sendConfirmationEmail(owner, policy);
      
      // Generate policy documents
      await _generatePolicyDocuments(policy);
      
      return PolicyIssuanceResult(
        success: true,
        policy: policy,
        errorMessage: null,
      );
    } catch (e) {
      return PolicyIssuanceResult(
        success: false,
        policy: null,
        errorMessage: 'Failed to issue policy: $e',
      );
    }
  }
  
  /// Renew an existing policy
  Future<PolicyIssuanceResult> renewPolicy({
    required Policy existingPolicy,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      // Process renewal payment
      final amount = _calculateInitialPayment(
        existingPolicy.plan,
        existingPolicy.paymentSchedule,
      );
      
      final paymentResult = await _paymentProcessor.processPayment(
        policyId: existingPolicy.id,
        amount: amount,
        paymentMethod: paymentMethod,
        schedule: existingPolicy.paymentSchedule,
      );
      
      if (!paymentResult.success) {
        return PolicyIssuanceResult(
          success: false,
          policy: null,
          errorMessage: 'Renewal payment failed',
        );
      }
      
      // Create renewed policy
      final renewedPolicy = Policy(
        id: _generatePolicyId(),
        policyNumber: _generatePolicyNumber(),
        ownerId: existingPolicy.ownerId,
        petId: existingPolicy.petId,
        quoteId: existingPolicy.quoteId,
        plan: existingPolicy.plan,
        issuedAt: DateTime.now(),
        effectiveDate: existingPolicy.expirationDate,
        expirationDate: existingPolicy.expirationDate.add(const Duration(days: 365)),
        status: PolicyStatus.active,
        paymentSchedule: existingPolicy.paymentSchedule,
      );
      
      // Save renewed policy
      await _firebaseService.savePolicy(renewedPolicy);
      
      return PolicyIssuanceResult(
        success: true,
        policy: renewedPolicy,
        errorMessage: null,
      );
    } catch (e) {
      return PolicyIssuanceResult(
        success: false,
        policy: null,
        errorMessage: 'Policy renewal failed: $e',
      );
    }
  }
  
  /// Cancel a policy
  Future<bool> cancelPolicy(String policyId, String reason) async {
    try {
      final policy = await _firebaseService.getPolicy(policyId);
      if (policy == null) return false;
      
      // Update policy status
      final cancelledPolicy = Policy(
        id: policy.id,
        policyNumber: policy.policyNumber,
        ownerId: policy.ownerId,
        petId: policy.petId,
        quoteId: policy.quoteId,
        plan: policy.plan,
        issuedAt: policy.issuedAt,
        effectiveDate: policy.effectiveDate,
        expirationDate: DateTime.now(),
        status: PolicyStatus.cancelled,
        paymentSchedule: policy.paymentSchedule,
        claims: policy.claims,
      );
      
      await _firebaseService.updatePolicy(cancelledPolicy);
      
      // TODO: Cancel recurring payments
      // TODO: Calculate and process any refunds
      // TODO: Send cancellation confirmation
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<Policy> _createPolicy({
    required Quote quote,
    required Owner owner,
    required Pet pet,
    required CoveragePlan selectedPlan,
    required PaymentSchedule paymentSchedule,
  }) async {
    final now = DateTime.now();
    final effectiveDate = now.add(const Duration(days: 1)); // Next day
    
    return Policy(
      id: _generatePolicyId(),
      policyNumber: _generatePolicyNumber(),
      ownerId: owner.id,
      petId: pet.id,
      quoteId: quote.id,
      plan: selectedPlan,
      issuedAt: now,
      effectiveDate: effectiveDate,
      expirationDate: effectiveDate.add(const Duration(days: 365)),
      status: PolicyStatus.active,
      paymentSchedule: paymentSchedule,
    );
  }
  
  double _calculateInitialPayment(CoveragePlan plan, PaymentSchedule schedule) {
    switch (schedule) {
      case PaymentSchedule.monthly:
        return plan.monthlyPremium;
      case PaymentSchedule.quarterly:
        return plan.monthlyPremium * 3;
      case PaymentSchedule.annually:
        return plan.annualPremium;
    }
  }
  
  Future<void> _sendConfirmationEmail(Owner owner, Policy policy) async {
    // TODO: Implement email sending
    print('Sending confirmation email to ${owner.email}');
  }
  
  Future<void> _generatePolicyDocuments(Policy policy) async {
    // TODO: Generate PDF policy documents
    print('Generating policy documents for ${policy.policyNumber}');
  }
  
  String _generatePolicyId() {
    return 'pol_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  String _generatePolicyNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PET-${timestamp.toString().substring(timestamp.toString().length - 8)}';
  }
}

/// Result of policy issuance
class PolicyIssuanceResult {
  final bool success;
  final Policy? policy;
  final String? errorMessage;
  
  PolicyIssuanceResult({
    required this.success,
    required this.policy,
    required this.errorMessage,
  });
}

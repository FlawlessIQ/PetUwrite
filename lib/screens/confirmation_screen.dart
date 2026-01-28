import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/checkout_state.dart';
import '../models/policy_exclusion.dart';
import '../services/draft_service.dart';
import '../services/policy_service.dart';
import '../services/user_session_service.dart';
import '../services/underwriting_case_service.dart';
import '../services/marketing_attribution_service.dart';
import '../ui/tokens.dart';
import '../ui/components/checkout_components.dart';
import '../ui/components/max_width.dart';

/// Step 4: Confirmation screen with policy details and PDF download
class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isCreatingPolicy = true;
  bool _policyCreated = false;
  String? _errorMessage;
  final _policyService = PolicyService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
    _createPolicy();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createPolicy() async {
    try {
      final provider = context.read<CheckoutProvider>();

      // Debug: Check if user is authenticated
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // In web/dev flows we may reach checkout without a signed-in user.
        // Firestore rules require request.auth, so ensure we have at least
        // an anonymous session before creating a policy.
        await FirebaseAuth.instance.signInAnonymously();
        user = FirebaseAuth.instance.currentUser;
      }

      print(
        '🔍 Creating policy for user: ${user?.uid} (anonymous=${user?.isAnonymous}, email=${user?.email})',
      );

      if (user == null) {
        throw Exception('User not authenticated - cannot create policy');
      }

      // Generate policy number
      final policyNumber = _generatePolicyNumber();
      print('🔍 Generated policy number: $policyNumber');

      // Phase 5: Fetch underwriting decision snapshot if caseId present.
      // Otherwise, use the snapshot carried forward from medical underwriting.
      Map<String, dynamic>? underwritingSnapshot =
          provider.underwritingSnapshot;
      List<PolicyExclusion>? decisionExclusions;
      final caseId = provider.underwritingCaseId;
      if (caseId != null && caseId.isNotEmpty) {
        final uwService = UnderwritingCaseService();
        final decision = await uwService.getCurrentDecision(caseId);
        if (decision == null) {
          throw Exception(
            'Underwriting decision missing. Please return to underwriting to complete review, then try again.',
          );
        }

        decisionExclusions = decision.exclusions;
        underwritingSnapshot = {
          'caseId': caseId,
          'decision': decision.toJson(),
          'capturedAt': DateTime.now().toIso8601String(),
        };
      }

      final hasDeclaredConditions =
          (provider.pet?.preExistingConditions ?? const <String>[]).any(
            (c) => c.trim().isNotEmpty && c.trim() != 'None',
          );

      if ((hasDeclaredConditions || provider.exclusions.isNotEmpty) &&
          underwritingSnapshot == null) {
        throw Exception(
          'Underwriting decision missing. Please return to underwriting to complete review, then try again.',
        );
      }

      // Stamp exclusions acknowledgement evidence (if present) onto snapshot.
      if (underwritingSnapshot != null) {
        final updated = Map<String, dynamic>.from(underwritingSnapshot);
        final ack =
            provider.underwritingSnapshot?['exclusionsAcknowledgements'];
        if (ack is Map) {
          updated['exclusionsAcknowledgements'] = ack;
        }
        final ackAt =
            provider.underwritingSnapshot?['exclusionsAcknowledgedAt'];
        if (ackAt != null) {
          updated['exclusionsAcknowledgedAt'] = ackAt;
        }
        underwritingSnapshot = updated;
      }

      // Persist pricing / coverage selection evidence at bind time.
      // This is separate from the plan persisted on the policy, and supports auditability.
      final selectedPlan = provider.selectedPlan;
      if (selectedPlan != null) {
        final updated = Map<String, dynamic>.from(
          underwritingSnapshot ?? <String, dynamic>{},
        );
        updated['pricingAtBind'] = {
          'capturedAt': DateTime.now().toIso8601String(),
          'plan': selectedPlan.toJson(),
          'pricingBreakdown': selectedPlan.pricingBreakdown?.toJson(),
        };
        underwritingSnapshot = updated;
      }

      // Create policy document
      final policy = await _policyService.createPolicy(
        pet: provider.pet!,
        owner: provider.ownerDetails!,
        plan: provider.selectedPlan!,
        payment: provider.paymentInfo!,
        policyNumber: policyNumber,
        underwritingCaseId: caseId,
        exclusions: decisionExclusions ?? provider.exclusions,
        underwritingSnapshot: underwritingSnapshot,
      );

      // Update provider with policy
      provider.setPolicy(policy);

      // Best-effort marketing attribution
      try {
        final premium = provider.selectedPlan?.monthlyPremium;
        final payment = provider.paymentInfo;
        await MarketingAttributionService().trackEvent(
          'purchase_completed',
          policyId: policy.policyId,
          premium: premium,
          code: payment?.couponCode,
          discountAmount: payment?.discountAmount,
        );
      } catch (_) {
        // Best-effort only.
      }

      // Clear any saved checkout progress / resume key on successful bind.
      try {
        await UserSessionService().clearPendingCheckout();
        await DraftService().clearAll();
      } catch (_) {
        // Ignore cleanup errors.
      }

      // Send email notification
      try {
        await _policyService.sendPolicyEmail(policy);
      } catch (e) {
        // Best-effort only; policy is already created.
        print('⚠️ Policy email failed (ignored): $e');
      }

      setState(() {
        _isCreatingPolicy = false;
        _policyCreated = true;
      });
    } catch (e) {
      print('❌ Policy creation failed: $e');
      print('❌ Policy creation failed: $e');

      // Extract more specific error information
      String errorMessage = e.toString();
      if (errorMessage.contains('permission-denied')) {
        errorMessage =
            'Permission denied: Unable to create policy. Please ensure you are signed in and try again.';
      } else if (errorMessage.contains('Failed to create policy:')) {
        // Extract the inner error
        final match = RegExp(
          r'Failed to create policy: (.+)',
        ).firstMatch(errorMessage);
        if (match != null) {
          errorMessage = match.group(1) ?? errorMessage;
        }
      }

      setState(() {
        _isCreatingPolicy = false;
        _errorMessage = errorMessage;
      });
    }
  }

  String _generatePolicyNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(
      4,
      '0',
    );
    return 'PU$year$random';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, provider, child) {
        if (_isCreatingPolicy) {
          return _buildLoadingState();
        }

        if (_errorMessage != null) {
          return _buildErrorState();
        }

        if (_policyCreated && provider.policy != null) {
          return _buildSuccessState(provider.policy!);
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Website home'),
            style: TextButton.styleFrom(foregroundColor: AppColors.deepGreen),
          ),
          const SizedBox(height: 18),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Creating your policy...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we finalize your coverage',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Website home'),
              style: TextButton.styleFrom(foregroundColor: AppColors.deepGreen),
            ),
            const SizedBox(height: 18),
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to create policy',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isCreatingPolicy = true;
                  _errorMessage = null;
                });
                _createPolicy();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return MaxWidth(
      maxWidth: 960,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Website home'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.deepGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Success Badge (subtle, not giant)
            ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 3),
                    color: const Color(0xFFE8F5F0),
                  ),
                  child: Icon(Icons.check, size: 48, color: AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Success Message
            Text(
              'You\'re Covered!',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your pet insurance policy is now active',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Policy Information Card
            CheckoutCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Policy Details',
                    padding: const EdgeInsets.only(bottom: 16),
                  ),
                  InfoRow(
                    label: 'Policy Number',
                    value: policy.policyNumber,
                    isBold: true,
                  ),
                  InfoRow(label: 'Pet Name', value: policy.pet.name),
                  InfoRow(label: 'Plan', value: policy.plan.name),
                  InfoRow(
                    label: 'Coverage Start',
                    value: dateFormat.format(policy.effectiveDate),
                  ),
                  InfoRow(
                    label: 'Coverage End',
                    value: dateFormat.format(policy.expirationDate),
                  ),
                  InfoRow(
                    label: 'Monthly Premium',
                    value: '\$${policy.plan.monthlyPremium.toStringAsFixed(2)}',
                    isBold: true,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Coverage Summary Card
            CheckoutCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Coverage Summary',
                    padding: const EdgeInsets.only(bottom: 16),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoverageMetric(
                          'Reimbursement',
                          policy.plan.coveragePercentage,
                          Icons.pie_chart_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoverageMetric(
                          'Deductible',
                          '\$${policy.plan.annualDeductible.toStringAsFixed(0)}',
                          Icons.attach_money,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoverageMetric(
                          'Annual Max',
                          '\$${(policy.plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}K',
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoverageMetric(
                          'Co-pay',
                          '${policy.plan.coPayPercentage.toInt()}%',
                          Icons.handshake_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Waiting Periods Card
            if (policy.plan.waitingPeriodsDays != null &&
                policy.plan.waitingPeriodsDays!.isNotEmpty)
              CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Waiting Periods',
                      padding: const EdgeInsets.only(bottom: 12),
                    ),
                    Text(
                      'Coverage starts on ${dateFormat.format(policy.effectiveDate)}, but some conditions have a waiting period. These are typical market standards:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(() {
                      final entries =
                          policy.plan.waitingPeriodsDays!.entries.toList(
                            growable: false,
                          )..sort((a, b) => a.key.compareTo(b.key));

                      return entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InfoRow(
                                label: _titleCase(e.key),
                                value: '${e.value} days',
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          )
                          .toList(growable: false);
                    })(),
                  ],
                ),
              ),
            if (policy.plan.waitingPeriodsDays != null &&
                policy.plan.waitingPeriodsDays!.isNotEmpty)
              const SizedBox(height: 20),

            // Next Steps Card
            CheckoutCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Next Steps',
                    padding: const EdgeInsets.only(bottom: 16),
                  ),
                  _buildNextStepRow(
                    '1',
                    'Check your email',
                    'Policy documents sent to ${policy.owner.email}',
                    Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildNextStepRow(
                    '2',
                    'Visit your vet',
                    'Your coverage starts on ${dateFormat.format(policy.effectiveDate)} (waiting periods apply)',
                    Icons.local_hospital_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildNextStepRow(
                    '3',
                    'File claims easily',
                    'Submit through our mobile app',
                    Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            PrimaryButton(
              text: 'Go to Dashboard',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/dashboard',
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              text: 'Download Policy PDF',
              onPressed: () => _downloadPDF(policy),
              icon: Icons.download,
            ),
            const SizedBox(height: 12),
            TertiaryButton(
              text: 'Contact Support',
              onPressed: () {
                // Open support
              },
              icon: Icons.support_agent,
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  Widget _buildCoverageMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br12,
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.green),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepRow(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPDF(PolicyDocument policy) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final pdfUrl = await _policyService.generatePolicyPDF(policy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('PDF downloaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                print('PDF URL: $pdfUrl');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

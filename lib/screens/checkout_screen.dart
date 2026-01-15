import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/checkout_state.dart';
import '../models/policy_exclusion.dart';
import '../models/pet.dart';
import '../services/quote_engine.dart';
import '../services/product_catalog.dart';
import '../services/draft_service.dart';
import '../services/user_session_service.dart';
import '../theme/clovara_theme.dart';
import 'review_screen.dart';
import 'owner_details_screen.dart';
import 'payment_screen.dart';
import 'confirmation_screen.dart';

/// Redesigned checkout screen with prominent Clovara branding
class CheckoutScreen extends StatefulWidget {
  final dynamic pet;
  final dynamic selectedPlan;
  final String? underwritingCaseId;
  final List<dynamic>? exclusions;
  final Map<String, dynamic>? underwritingSnapshot;

  const CheckoutScreen({
    super.key,
    required this.pet,
    required this.selectedPlan,
    this.underwritingCaseId,
    this.exclusions,
    this.underwritingSnapshot,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize checkout provider with pet and plan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Convert dynamic pet to Pet object if needed
        Pet petObject;
        if (widget.pet is Pet) {
          petObject = widget.pet as Pet;
        } else if (widget.pet is Map<String, dynamic>) {
          petObject = Pet.fromJson(widget.pet as Map<String, dynamic>);
        } else {
          // Handle invalid type
          print('ERROR: Invalid pet type: ${widget.pet.runtimeType}');
          print('Pet data: ${widget.pet}');
          return;
        }
        
        // Convert dynamic plan to Plan object if needed
        Plan planObject;
        if (widget.selectedPlan is Plan) {
          planObject = widget.selectedPlan as Plan;
        } else if (widget.selectedPlan is Map<String, dynamic>) {
          planObject = Plan.fromJson(widget.selectedPlan as Map<String, dynamic>);
        } else {
          // Check if it's a PlanData object (from static plans in plan_selection_screen)
          try {
            final planData = widget.selectedPlan;
            // Convert PlanData to Plan
            final monthlyPrice = planData.monthlyPrice ?? planData.monthlyPremium ?? 0.0;
            final reimbursement = planData.reimbursement ?? 80;
            final annualLimitRaw = planData.annualLimit ?? planData.maxAnnualCoverage;
            final maxAnnualCoverage = (annualLimitRaw ?? 10000);

            planObject = Plan(
              type: _getPlanTypeFromName(planData.name ?? 'Basic'),
              name: planData.name ?? 'Unknown Plan',
              description: 'Pet insurance coverage',
              pricingBasePremium: monthlyPrice is num ? monthlyPrice.toDouble() : 0.0,
              monthlyPremium: monthlyPrice is num ? monthlyPrice.toDouble() : 0.0,
              annualDeductible: (planData.annualDeductible ?? 500).toDouble(),
              coPayPercentage: (100 - reimbursement).toDouble(),
              maxAnnualCoverage: maxAnnualCoverage is num ? maxAnnualCoverage.toDouble() : 10000.0,
              maxLifetimeCoverage: null,
              numberOfPets: 1,
              multiPetDiscount: 0.0,
              reimbursementPercent: reimbursement is num ? reimbursement.toInt() : 80,
              features: List<String>.from(planData.features ?? []),
              exclusions: [],
            );
          } catch (e) {
            print('ERROR: Invalid plan type: ${widget.selectedPlan.runtimeType}');
            print('Plan data: ${widget.selectedPlan}');
            print('Error: $e');
            return;
          }
        }
        
        context.read<CheckoutProvider>().initialize(
              pet: petObject,
              plan: planObject,
            );

        // Phase 5: Set underwriting metadata if present
        final rawExclusions = widget.exclusions;
        List<PolicyExclusion>? parsedExclusions;
        if (rawExclusions is List) {
          parsedExclusions = rawExclusions
              .map((e) {
                if (e is PolicyExclusion) return e;
                if (e is String) {
                  final name = e.trim();
                  if (name.isEmpty) return null;
                  return PolicyExclusion(
                    conditionName: name,
                    scope: 'condition',
                    effectiveDate: DateTime.now(),
                    notes: 'Rule exclusion',
                  );
                }
                if (e is Map) {
                  return PolicyExclusion.fromJson(
                    e.cast<String, dynamic>(),
                  );
                }
                return null;
              })
              .whereType<PolicyExclusion>()
              .toList();
        }

        final snapshot = widget.underwritingSnapshot ??
            ((parsedExclusions != null && parsedExclusions.isNotEmpty)
                ? {
                    'capturedAt': DateTime.now().toIso8601String(),
                    'source': 'checkout_route',
                    'exclusions': parsedExclusions
                        .map((e) => e.toJson())
                        .toList(growable: false),
                  }
                : null);

        if ((widget.underwritingCaseId != null &&
                widget.underwritingCaseId!.isNotEmpty) ||
            (parsedExclusions != null && parsedExclusions.isNotEmpty) ||
            snapshot != null) {
          context.read<CheckoutProvider>().setUnderwritingMetadata(
                caseId: widget.underwritingCaseId,
                exclusions: parsedExclusions,
                snapshot: snapshot,
              );
        }

        // Restore pending checkout snapshot (if it matches this pet/plan).
        () async {
          try {
            final pending = await UserSessionService().getPendingCheckout();
            if (pending == null) return;

            final pendingPet = pending['pet'];
            final pendingPlan = pending['selectedPlan'];

            final pendingPetName = (pendingPet is Map)
                ? (pendingPet['name']?.toString() ?? pendingPet['petName']?.toString() ?? '')
                : '';
            final pendingPlanName = (pendingPlan is Map)
                ? (pendingPlan['name']?.toString() ?? '')
                : '';

            final matchesPet = pendingPetName.trim().isEmpty || pendingPetName.trim() == petObject.name.trim();
            final matchesPlan = pendingPlanName.trim().isEmpty || pendingPlanName.trim() == planObject.name.trim();

            if (!matchesPet || !matchesPlan) return;

            final provider = context.read<CheckoutProvider>();

            final ownerJson = (pending['ownerDetails'] is Map)
                ? (pending['ownerDetails'] as Map).cast<String, dynamic>()
                : null;
            if (ownerJson != null) {
              provider.setOwnerDetails(OwnerDetails.fromJson(ownerJson));
            }

            final underwritingCaseId = pending['underwritingCaseId']?.toString();
            final exclusionsRaw = pending['exclusions'];
            final exclusions = (exclusionsRaw is List)
                ? exclusionsRaw
                    .whereType<Map>()
                    .map((e) => PolicyExclusion.fromJson(e.cast<String, dynamic>()))
                    .toList()
                : null;
            final uwSnapshot = (pending['underwritingSnapshot'] as Map?)?.cast<String, dynamic>();
            if ((underwritingCaseId != null && underwritingCaseId.trim().isNotEmpty) ||
                (exclusions != null && exclusions.isNotEmpty) ||
                uwSnapshot != null) {
              provider.setUnderwritingMetadata(
                caseId: underwritingCaseId,
                exclusions: exclusions,
                snapshot: uwSnapshot,
              );
            }

            final stepStr = pending['currentStep']?.toString() ?? '';
            final canGoPayment = provider.ownerDetails != null;
            if (stepStr == 'payment' && canGoPayment) {
              provider.goToStep(CheckoutStep.payment);
            } else if (stepStr == 'ownerDetails' || stepStr == 'payment') {
              provider.goToStep(CheckoutStep.ownerDetails);
            }
          } catch (e) {
            print('⚠️ Error restoring pending checkout: $e');
          }
        }();
      } catch (e, stackTrace) {
        print('ERROR initializing checkout: $e');
        print('Stack trace: $stackTrace');
      }
    });
  }

  Map<String, dynamic> _buildCheckoutSnapshot(CheckoutProvider provider) {
    return {
      'pet': provider.pet?.toJson(),
      'selectedPlan': provider.selectedPlan?.toJson(),
      'ownerDetails': provider.ownerDetails?.toJson(),
      'underwritingCaseId': provider.underwritingCaseId,
      'exclusions': provider.exclusions.map((e) => e.toJson()).toList(growable: false),
      'underwritingSnapshot': provider.underwritingSnapshot,
      'currentStep': provider.currentStep.toString().split('.').last,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveAndExitCheckout(BuildContext context) async {
    final provider = context.read<CheckoutProvider>();

    final snapshot = _buildCheckoutSnapshot(provider);
    await UserSessionService().savePendingCheckout(snapshot);

    // Save server draft so resume-by-code works.
    final state = provider.currentStep == CheckoutStep.payment ? 'CHECKOUT_PAYMENT' : 'CHECKOUT_OWNER';
    await DraftService().upsertCheckoutDraft(state: state, checkoutData: snapshot);

    if (!context.mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _copyResumeCodeToClipboard(BuildContext context) async {
    try {
      final draftService = DraftService();
      final resumeKey = await draftService.getOrCreateLocalResumeKey();
      await Clipboard.setData(
        ClipboardData(text: draftService.encodeForSharing(resumeKey)),
      );
      if (!context.mounted) return;
      final pretty = draftService.prettyCode(resumeKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume code copied: $pretty')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy resume code')),
      );
    }
  }
  
  PlanType _getPlanTypeFromName(String name) {
    switch (name.toLowerCase()) {
      case 'basic':
        return PlanType.basic;
      case 'standard':
        return PlanType.standard;
      case 'plus':
        return PlanType.plus;
      case 'premium':
        return PlanType.premium;
      case 'unlimited':
        return PlanType.unlimited;
      default:
        return PlanType.standard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final provider = context.read<CheckoutProvider>();
        
        // If on confirmation screen, allow back
        if (provider.currentStep == CheckoutStep.confirmation) {
          return true;
        }
        
        // Show confirmation dialog if not on first step
        if (provider.currentStep != CheckoutStep.review) {
          final shouldExit = await _showExitConfirmation(context);
          return shouldExit ?? false;
        }
        
        return true;
      },
      child: Scaffold(
        backgroundColor: ClovaraColors.forest,
        body: SafeArea(
          child: Consumer<CheckoutProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  _buildBrandedHeader(provider),
                  if (provider.error != null) _buildErrorBanner(provider.error!),
                  _buildStepIndicator(provider),
                  Expanded(
                    child: _buildStepContent(provider),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandedHeader(CheckoutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ClovaraColors.forest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              if (provider.currentStep != CheckoutStep.confirmation)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 24),
              
              // Logo/Title
              Expanded(
                child: Text(
                  'Clovara',
                  style: ClovaraTypography.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Close Button
              if (provider.currentStep != CheckoutStep.confirmation)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => _handleExit(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 24),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Current Step Title
          Text(
            provider.getStepName(provider.currentStep),
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.clover,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(CheckoutProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: List.generate(CheckoutStep.values.length, (index) {
              final step = CheckoutStep.values[index];
              final isCurrent = provider.currentStep == step;
              final isPast = provider.currentStepIndex > index;
              final isActive = isCurrent || isPast;
              
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? ClovaraColors.clover
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < CheckoutStep.values.length - 1)
                      const SizedBox(width: 8),
                  ],
                ),
              );
            }),
          ),
          
          const SizedBox(height: 20),
          
          // Step circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: CheckoutStep.values.map((step) {
              final index = step.index;
              final isCurrent = provider.currentStep == step;
              final isPast = provider.currentStepIndex > index;
              final isActive = isCurrent || isPast;

              return Expanded(
                child: _buildStepItem(
                  step: step,
                  isActive: isActive,
                  isCurrent: isCurrent,
                  isPast: isPast,
                  provider: provider,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required CheckoutStep step,
    required bool isActive,
    required bool isCurrent,
    required bool isPast,
    required CheckoutProvider provider,
  }) {
    final stepName = provider.getStepName(step);
    final stepIcon = provider.getStepIcon(step);

    Color circleColor;
    Color iconColor;
    Color textColor;

    if (isPast) {
      circleColor = ClovaraColors.clover;
      iconColor = Colors.white;
      textColor = ClovaraColors.forest;
    } else if (isCurrent) {
      circleColor = ClovaraColors.clover;
      iconColor = Colors.white;
      textColor = ClovaraColors.forest;
    } else {
      circleColor = Colors.grey.shade200;
      iconColor = Colors.grey.shade400;
      textColor = Colors.grey.shade500;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 48 : 40,
          height: isCurrent ? 48 : 40,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            boxShadow: isCurrent ? [
              BoxShadow(
                color: ClovaraColors.clover.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : [],
          ),
          child: Center(
            child: isPast
                ? Icon(
                    Icons.check_rounded,
                    color: iconColor,
                    size: 24,
                  )
                : Text(
                    stepIcon,
                    style: TextStyle(
                      fontSize: isCurrent ? 22 : 20,
                      color: iconColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stepName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.red.shade700,
            onPressed: () {
              context.read<CheckoutProvider>().setError(null);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(CheckoutProvider provider) {
    // Wrap content in white background container for consistency
    Widget content;
    
    switch (provider.currentStep) {
      case CheckoutStep.review:
        content = const ReviewScreen();
        break;
      case CheckoutStep.ownerDetails:
        content = const OwnerDetailsScreen();
        break;
      case CheckoutStep.payment:
        content = const PaymentScreen();
        break;
      case CheckoutStep.confirmation:
        content = const ConfirmationScreen();
        break;
    }
    
    return Container(
      color: Colors.grey.shade50,
      child: content,
    );
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exit Checkout?',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
          ],
        ),
        content: Text(
          'Save your progress and finish later, or exit without saving.',
          style: ClovaraTypography.body.copyWith(
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: ClovaraColors.forest,
              side: BorderSide(color: Colors.grey.shade300, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Stay',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () => _copyResumeCodeToClipboard(context),
            child: const Text(
              'Copy resume code',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => _saveAndExitCheckout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClovaraColors.clover,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              'Save & exit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _handleExit(BuildContext context) async {
    final shouldExit = await _showExitConfirmation(context);
    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }
}

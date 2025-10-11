import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkout_state.dart';
import '../models/pet.dart';
import '../services/quote_engine.dart';
import '../theme/petuwrite_theme.dart';
import 'review_screen.dart';
import 'owner_details_screen.dart';
import 'payment_screen.dart';
import 'confirmation_screen.dart';

/// Redesigned checkout screen with prominent PetUwrite branding
class CheckoutScreen extends StatefulWidget {
  final dynamic pet;
  final dynamic selectedPlan;

  const CheckoutScreen({
    super.key,
    required this.pet,
    required this.selectedPlan,
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
      // Convert dynamic pet to Pet object if needed
      Pet petObject;
      if (widget.pet is Pet) {
        petObject = widget.pet as Pet;
      } else if (widget.pet is Map<String, dynamic>) {
        petObject = Pet.fromJson(widget.pet as Map<String, dynamic>);
      } else {
        // Handle invalid type
        print('ERROR: Invalid pet type: ${widget.pet.runtimeType}');
        return;
      }
      
      // Convert dynamic plan to Plan object if needed
      Plan planObject;
      if (widget.selectedPlan is Plan) {
        planObject = widget.selectedPlan as Plan;
      } else if (widget.selectedPlan is Map<String, dynamic>) {
        planObject = Plan.fromJson(widget.selectedPlan as Map<String, dynamic>);
      } else {
        print('ERROR: Invalid plan type: ${widget.selectedPlan.runtimeType}');
        return;
      }
      
      context.read<CheckoutProvider>().initialize(
            pet: petObject,
            plan: planObject,
          );
    });
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
        backgroundColor: PetUwriteColors.kPrimaryNavy,
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
        color: PetUwriteColors.kPrimaryNavy,
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
                  'PetUwrite',
                  style: PetUwriteTypography.h2.copyWith(
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
            style: PetUwriteTypography.h3.copyWith(
              color: PetUwriteColors.kSecondaryTeal,
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
                              ? PetUwriteColors.kSecondaryTeal
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
      circleColor = PetUwriteColors.kSecondaryTeal;
      iconColor = Colors.white;
      textColor = PetUwriteColors.kPrimaryNavy;
    } else if (isCurrent) {
      circleColor = PetUwriteColors.kSecondaryTeal;
      iconColor = Colors.white;
      textColor = PetUwriteColors.kPrimaryNavy;
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
                color: PetUwriteColors.kSecondaryTeal.withOpacity(0.4),
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
              style: PetUwriteTypography.h3.copyWith(
                color: PetUwriteColors.kPrimaryNavy,
              ),
            ),
          ],
        ),
        content: Text(
          'Your progress will be lost if you exit now. Are you sure you want to leave?',
          style: PetUwriteTypography.bodyLarge.copyWith(
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
              foregroundColor: PetUwriteColors.kPrimaryNavy,
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

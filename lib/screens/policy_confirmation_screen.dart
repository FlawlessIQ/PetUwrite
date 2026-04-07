import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/checkout_state.dart';
import '../services/policy_service.dart';
import '../theme/clovara_theme.dart';
import '../ui/tokens.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/components/checkout_ui/checkout_card.dart';
import '../ui/components/checkout_ui/checkout_inline_banner.dart';

/// Premium policy confirmation screen - Post-purchase success
class PolicyConfirmationScreen extends StatefulWidget {
  const PolicyConfirmationScreen({super.key});

  @override
  State<PolicyConfirmationScreen> createState() =>
      _PolicyConfirmationScreenState();
}

class _PolicyConfirmationScreenState extends State<PolicyConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final PolicyService _policyService = PolicyService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<CheckoutProvider>(
          builder: (context, provider, child) {
            final policy = provider.policy;

            if (policy == null) {
              return _buildPlaceholder(context);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 768;

                // Website-like centered column on web/desktop.
                return MaxWidth(
                  maxWidth: 980,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 16,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isDesktop ? 48 : 24,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ClovaraLogo(
                              size: ClovaraLogoSize.small,
                              showText: true,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final shouldLeave = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Back to website home?',
                                      ),
                                      content: const Text(
                                        'This will take you back to the marketing site home.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Go to home'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldLeave != true) return;
                                  if (!context.mounted) return;
                                  context.go('/');
                                },
                                icon: const Icon(Icons.home_outlined, size: 18),
                                label: const Text('Website home'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.deepGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSuccessHeader(policy),
                            const SizedBox(height: 40),

                            if (isDesktop)
                              _buildDesktopLayout(policy)
                            else
                              _buildMobileLayout(policy),

                            const SizedBox(height: 32),
                            _buildActionButtons(context, policy),
                            const SizedBox(height: 24),
                            _buildEmailNotice(policy),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Success header with checkmark and message
  Widget _buildSuccessHeader(PolicyDocument policy) {
    final effectiveDateLabel = DateFormat('MMM d, yyyy').format(
      policy.effectiveDate,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.success,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to Clovara!',
          style: TextStyle(
            fontFamily: ClovaraTypography.poppins,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.deepGreen,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${policy.pet.name}\'s ${policy.plan.name} coverage begins $effectiveDateLabel',
          style: TextStyle(
            fontFamily: ClovaraTypography.inter,
            fontSize: 18,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Desktop 2-column layout
  Widget _buildDesktopLayout(PolicyDocument policy) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Policy details
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPolicyCard(policy),
              const SizedBox(height: 24),
              _buildCoverageSummary(policy),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right column - Next steps
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildNextStepsCard(policy)],
          ),
        ),
      ],
    );
  }

  /// Mobile stacked layout
  Widget _buildMobileLayout(PolicyDocument policy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPolicyCard(policy),
        const SizedBox(height: 24),
        _buildCoverageSummary(policy),
        const SizedBox(height: 24),
        _buildNextStepsCard(policy),
      ],
    );
  }

  /// Clean policy card with key details
  Widget _buildPolicyCard(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return CheckoutCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: AppRadii.r20,
                topRight: AppRadii.r20,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POLICY NUMBER',
                      style: TextStyle(
                        fontFamily: ClovaraTypography.inter,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      policy.policyNumber,
                      style: TextStyle(
                        fontFamily: ClovaraTypography.inter,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontFamily: ClovaraTypography.inter,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pet & Plan Details
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet info
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          policy.pet.name[0].toUpperCase(),
                          style: TextStyle(
                            fontFamily: ClovaraTypography.poppins,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policy.pet.name,
                            style: TextStyle(
                              fontFamily: ClovaraTypography.poppins,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${policy.pet.breed} • ${policy.pet.ageInYears} ${policy.pet.ageInYears == 1 ? 'year' : 'years'} old',
                            style: TextStyle(
                              fontFamily: ClovaraTypography.inter,
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 24),

                // Plan & dates
                _buildDetailRow('Plan', policy.plan.name),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'Effective Date',
                  dateFormat.format(policy.effectiveDate),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'Renewal Date',
                  dateFormat.format(policy.expirationDate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: ClovaraTypography.inter,
            fontSize: 14,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: ClovaraTypography.inter,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  /// Coverage summary with clear benefits
  Widget _buildCoverageSummary(PolicyDocument policy) {
    return CheckoutCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your coverage at a glance',
            style: TextStyle(
              fontFamily: ClovaraTypography.poppins,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 20),

          // Benefits grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBenefitCard(
                label: 'Monthly premium',
                value: '\$${policy.plan.monthlyPremium.toStringAsFixed(2)}',
                subtext:
                    '\$${(policy.plan.monthlyPremium * 12).toStringAsFixed(0)}/year',
              ),
              _buildBenefitCard(
                label: 'Reimbursement',
                value: '${100 - policy.plan.coPayPercentage.toInt()}%',
                subtext: 'of eligible costs',
              ),
              _buildBenefitCard(
                label: 'Annual deductible',
                value: '\$${policy.plan.annualDeductible.toStringAsFixed(0)}',
                subtext: 'per year',
              ),
              _buildBenefitCard(
                label: 'Annual limit',
                value: '\$${_formatCurrency(policy.plan.maxAnnualCoverage)}',
                subtext: 'max coverage',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard({
    required String label,
    required String value,
    required String subtext,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make cards responsive
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 24) / 4;

        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadii.br12,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: ClovaraTypography.inter,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontFamily: ClovaraTypography.poppins,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyle(
                  fontFamily: ClovaraTypography.inter,
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Next steps timeline
  Widget _buildNextStepsCard(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd');

    return CheckoutCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next',
            style: TextStyle(
              fontFamily: ClovaraTypography.poppins,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 20),

          _buildTimelineStep(
            icon: Icons.email_outlined,
            title: 'Today',
            description: 'Policy documents sent to your email',
            isCompleted: true,
          ),
          _buildTimelineStep(
            icon: Icons.shield_outlined,
            title: dateFormat.format(policy.effectiveDate),
            description: 'Coverage becomes active',
            isCompleted: false,
          ),
          _buildTimelineStep(
            icon: Icons.file_upload_outlined,
            title: 'Anytime',
            description: 'File claims online in minutes',
            isCompleted: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success : AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? AppColors.success : AppColors.border,
                  width: 2,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted ? Colors.white : AppColors.textMuted,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8, bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: ClovaraTypography.inter,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: ClovaraTypography.inter,
                    fontSize: 14,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Action buttons
  Widget _buildActionButtons(BuildContext context, PolicyDocument policy) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 768;

        if (isDesktop) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Download Policy',
                      icon: Icons.download_rounded,
                      isPrimary: false,
                      onTap: () => _downloadPolicy(context, policy),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Go to Dashboard',
                      icon: Icons.arrow_forward,
                      isPrimary: true,
                      onTap: () => context.go('/app'),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionButton(
                label: 'Go to Dashboard',
                icon: Icons.arrow_forward,
                isPrimary: true,
                onTap: () => context.go('/app'),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                label: 'Download Policy',
                icon: Icons.download_rounded,
                isPrimary: false,
                onTap: () => _downloadPolicy(context, policy),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.green : AppColors.surface1,
          foregroundColor: isPrimary ? Colors.white : AppColors.text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.br12,
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: ClovaraTypography.inter,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }

  /// Email notice
  Widget _buildEmailNotice(PolicyDocument policy) {
    return CheckoutInlineBanner(
      tone: CheckoutInlineBannerTone.info,
      title: 'Confirmation sent',
      message: 'Check ${policy.owner.email} for details',
    );
  }

  /// Placeholder when no policy
  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 20),
            Text(
              'No policy data available',
              style: TextStyle(
                fontFamily: ClovaraTypography.poppins,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please complete the checkout process',
              style: TextStyle(
                fontFamily: ClovaraTypography.inter,
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _downloadPolicy(
    BuildContext context,
    PolicyDocument policy,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating policy PDF...')),
      );

      final pdfUrl = await _policyService.generatePolicyPDF(policy);
      final pdfUri = Uri.tryParse(pdfUrl);
      if (pdfUri == null) {
        throw Exception('Invalid PDF URL');
      }

      final opened = await launchUrl(
        pdfUri,
        mode: LaunchMode.platformDefault,
      );
      if (!opened) {
        throw Exception('Unable to open generated PDF');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Policy PDF opened successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open policy PDF: ${e.toString()}'),
          backgroundColor: ClovaraColors.kError,
        ),
      );
    }
  }
}

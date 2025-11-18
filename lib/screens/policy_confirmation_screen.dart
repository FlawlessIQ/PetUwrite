import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/checkout_state.dart';
import '../theme/clovara_theme.dart';

/// World-class policy confirmation screen after successful purchase
class PolicyConfirmationScreen extends StatefulWidget {
  const PolicyConfirmationScreen({super.key});

  @override
  State<PolicyConfirmationScreen> createState() => _PolicyConfirmationScreenState();
}

class _PolicyConfirmationScreenState extends State<PolicyConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _checkmarkAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _contentAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
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
      backgroundColor: ClovaraColors.forest,
      body: SafeArea(
        child: Consumer<CheckoutProvider>(
          builder: (context, provider, child) {
            final policy = provider.policy;
            
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Success Section
                  _buildHeroSection(),
                  
                  // Main Content Area
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          if (policy != null) ...[
                            // Digital Policy Card
                            FadeTransition(
                              opacity: _contentAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ).animate(_contentAnimation),
                                child: _buildDigitalPolicyCard(policy),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Pet Profile Section
                            _buildPetProfileSection(policy),
                            const SizedBox(height: 20),
                            
                            // Coverage Highlights
                            _buildCoverageHighlights(policy),
                            const SizedBox(height: 20),
                            
                            // What's Next Timeline
                            _buildWhatsNextSection(policy),
                            const SizedBox(height: 24),
                            
                            // Action Cards
                            _buildActionCards(context, policy),
                            const SizedBox(height: 20),
                            
                            // Email Confirmation Footer
                            _buildEmailConfirmation(policy),
                          ] else ...[
                            _buildPlaceholderContent(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hero section with animated success message
  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          // Animated Success Checkmark
          ScaleTransition(
            scale: _checkmarkAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ClovaraColors.clover,
                    ClovaraColors.clover.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ClovaraColors.clover.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 70,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Success Message
          FadeTransition(
            opacity: _contentAnimation,
            child: Column(
              children: [
                Text(
                  'Welcome to PetUwrite!',
                  style: ClovaraTypography.h2.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your pet is now protected',
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.clover,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Digital policy card with glassmorphism effect
  Widget _buildDigitalPolicyCard(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            ClovaraColors.forest,
            ClovaraColors.forest.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.forest.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _PolicyCardPatternPainter(),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'POLICY',
                          style: ClovaraTypography.bodySmall.copyWith(
                            color: ClovaraColors.clover,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          policy.policyNumber,
                          style: ClovaraTypography.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade400,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ACTIVE',
                            style: ClovaraTypography.bodySmall.copyWith(
                              color: Colors.green.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Key Info Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildPolicyInfoItem(
                        'Effective Date',
                        dateFormat.format(policy.effectiveDate),
                        Icons.calendar_today_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPolicyInfoItem(
                        'Plan Type',
                        policy.plan.name,
                        Icons.shield_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPolicyInfoItem(
                        'Monthly Premium',
                        '\$${policy.plan.monthlyPremium.toStringAsFixed(2)}',
                        Icons.payments_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPolicyInfoItem(
                        'Coverage',
                        '\$${_formatCurrency(policy.plan.maxAnnualCoverage)}',
                        Icons.verified_user_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: ClovaraColors.clover.withOpacity(0.7),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: ClovaraTypography.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: ClovaraTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  /// Pet profile section
  Widget _buildPetProfileSection(PolicyDocument policy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pet Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  ClovaraColors.clover.withOpacity(0.2),
                  ClovaraColors.forest.withOpacity(0.1),
                ],
              ),
            ),
            child: Center(
              child: Text(
                policy.pet.name[0].toUpperCase(),
                style: ClovaraTypography.h1.copyWith(
                  color: ClovaraColors.forest,
                  fontSize: 36,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Pet Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.pet.name,
                  style: ClovaraTypography.h3.copyWith(
                    color: ClovaraColors.forest,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${policy.pet.breed} • ${policy.pet.ageInYears} ${policy.pet.ageInYears == 1 ? 'year' : 'years'} old',
                  style: ClovaraTypography.body.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Insured Pet',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.clover,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Checkmark Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Coverage highlights grid
  Widget _buildCoverageHighlights(PolicyDocument policy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ClovaraColors.clover.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: ClovaraColors.clover,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Coverage Highlights',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Coverage Grid
          Row(
            children: [
              Expanded(
                child: _buildCoverageItem(
                  '${100 - policy.plan.coPayPercentage}%',
                  'Reimbursement',
                  Icons.percent_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCoverageItem(
                  '\$${policy.plan.annualDeductible}',
                  'Deductible',
                  Icons.receipt_long_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCoverageItem(
                  '\$${_formatCurrency(policy.plan.maxAnnualCoverage)}',
                  'Annual Limit',
                  Icons.account_balance_wallet_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCoverageItem(
                  '\$${policy.plan.annualDeductible.toInt()}',
                  'Annual Deductible',
                  Icons.medical_services_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageItem(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: ClovaraTypography.bodySmall.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// What's next timeline
  Widget _buildWhatsNextSection(PolicyDocument policy) {
    final dateFormat = DateFormat('MMM dd');
    final effectiveDate = policy.effectiveDate;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ClovaraColors.forest.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timeline_rounded,
                  color: ClovaraColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'What\'s Next',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Timeline Items
          _buildTimelineItem(
            'Today',
            'Policy documents sent to your email',
            Icons.email_rounded,
            true,
            Colors.green,
          ),
          _buildTimelineItem(
            dateFormat.format(effectiveDate),
            'Coverage becomes active',
            Icons.shield_rounded,
            false,
            ClovaraColors.clover,
          ),
          _buildTimelineItem(
            'Anytime',
            'File your first claim online',
            Icons.file_upload_rounded,
            false,
            Colors.blue,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String date,
    String description,
    IconData icon,
    bool isCompleted,
    Color color, {
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
                color: isCompleted ? color : color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted ? Colors.white : color,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Action cards for key actions
  Widget _buildActionCards(BuildContext context, PolicyDocument policy) {
    return Column(
      children: [
        // Download Policy Card
        _buildActionCard(
          context: context,
          title: 'Download Policy',
          subtitle: 'Get your full policy documents (PDF)',
          icon: Icons.download_rounded,
          iconColor: ClovaraColors.clover,
          onTap: () {
            // TODO: Implement policy download
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloading policy documents...')),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // View Dashboard Card
        _buildActionCard(
          context: context,
          title: 'Go to Dashboard',
          subtitle: 'Manage your policy and file claims',
          icon: Icons.dashboard_rounded,
          iconColor: ClovaraColors.forest,
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
        ),
        const SizedBox(height: 12),
        
        // Support Card
        _buildActionCard(
          context: context,
          title: 'Contact Support',
          subtitle: 'We\'re here to help 24/7',
          icon: Icons.support_agent_rounded,
          iconColor: Colors.blue,
          onTap: () {
            // TODO: Implement support contact
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening support chat...')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ClovaraTypography.body.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Email confirmation footer
  Widget _buildEmailConfirmation(PolicyDocument policy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_read_rounded,
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmation Sent',
                  style: ClovaraTypography.body.copyWith(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check ${policy.owner.email} for details',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder content when no policy data available
  Widget _buildPlaceholderContent(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.info_outline_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No policy data available',
            style: ClovaraTypography.h3.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please complete the checkout process',
            style: ClovaraTypography.body.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClovaraColors.clover,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
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
}

/// Custom painter for policy card background pattern
class _PolicyCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw diagonal lines
    for (var i = -size.height; i < size.width + size.height; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

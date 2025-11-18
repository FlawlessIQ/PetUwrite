import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/clovara_theme.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../widgets/clovara_icons.dart';

/// Clovara Homepage - Landing page with navigation options
/// 
/// Features:
/// - Clean single-page layout with logo
/// - 3 action cards: Get Quote, File Claim, Sign In
/// - Fully responsive design (mobile & desktop)
/// - Brand-consistent Clovara styling
/// - No scrolling required on standard screens
class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 900;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Header with logo
                      _buildHeader(context, isMobile),
                      
                      // Spacer
                      const SizedBox(height: 24),
                      
                      // Main content (centered)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 20 : 40,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Tagline
                                _buildTagline(context, isMobile),
                                
                                SizedBox(height: isMobile ? 32 : 48),
                                
                                // Action Cards
                                _buildActionCards(context, isSmallScreen, isMobile),
                                
                                SizedBox(height: isMobile ? 32 : 48),
                                
                                // Features
                                _buildFeaturesSection(context, isSmallScreen, isMobile),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Footer
                      _buildFooter(context, isMobile),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Header with Clovara logo
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClovaraColors.mist,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ClovaraColors.clover.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: SvgPicture.asset(
              'assets/images/clovara_mark_refined.svg',
              width: isMobile ? 40 : 56,
              height: isMobile ? 40 : 56,
            ),
          ),
          const SizedBox(width: 16),
          // Brand name
          Text(
            'Clovara',
            style: ClovaraTypography.h1.copyWith(
              color: ClovaraColors.forest,
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  /// Hero tagline
  Widget _buildTagline(BuildContext context, bool isMobile) {
    return Column(
      children: [
        Text(
          'Pet Insurance, Reimagined',
          style: ClovaraTypography.h2.copyWith(
            color: ClovaraColors.forest,
            fontSize: isMobile ? 24 : 36,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Quote → Decide → Payout, in minutes.',
          style: ClovaraTypography.body.copyWith(
            color: ClovaraColors.slate,
            fontSize: isMobile ? 16 : 20,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Action cards in grid layout
  Widget _buildActionCards(BuildContext context, bool isSmallScreen, bool isMobile) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: isSmallScreen
          ? Column(
              children: [
                _buildActionCard(
                  context: context,
                  iconName: ClovaraIcons.paw,
                  title: 'Get a Quote',
                  subtitle: 'AI-powered quotes in minutes',
                  color: Colors.white,
                  isMobile: isMobile,
                  onTap: () => Navigator.pushNamed(context, '/conversational-quote'),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context: context,
                  iconName: ClovaraIcons.stethoscope,
                  title: 'File a Claim',
                  subtitle: 'Quick claims submission',
                  color: Colors.white,
                  isMobile: isMobile,
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerHomeScreen(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context: context,
                  icon: Icons.account_circle_outlined,
                  title: 'Sign In',
                  subtitle: 'Access your account',
                  color: Colors.white,
                  isMobile: isMobile,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _buildActionCard(
                    context: context,
                    iconName: ClovaraIcons.paw,
                    title: 'Get a Quote',
                    subtitle: 'AI-powered quotes in minutes',
                    color: Colors.white,
                    isMobile: false,
                    onTap: () => Navigator.pushNamed(context, '/conversational-quote'),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: _buildActionCard(
                    context: context,
                    iconName: ClovaraIcons.stethoscope,
                    title: 'File a Claim',
                    subtitle: 'Quick claims submission',
                    color: Colors.white,
                    isMobile: false,
                    onTap: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomerHomeScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    title: 'Sign In',
                    subtitle: 'Access your account',
                    color: Colors.white,
                    isMobile: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// Compact action card widget
  Widget _buildActionCard({
    required BuildContext context,
    IconData? icon,
    String? iconName,
    required String title,
    required String subtitle,
    required Color color,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100, // Fixed short height
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 280,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: ClovaraColors.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ClovaraColors.clover.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: iconName != null
                    ? ClovaraIcon(
                        iconName,
                        size: 28,
                        color: Colors.white,
                      )
                    : Icon(
                        icon,
                        size: 28,
                        color: Colors.white,
                      ),
              ),
              
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: ClovaraTypography.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    Text(
                      subtitle,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Features/Stats section - Clovara specific
  Widget _buildFeaturesSection(BuildContext context, bool isSmallScreen, bool isMobile) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(
        children: [
          // Section title
          Text(
            'Why Choose Clovara?',
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 18 : 22,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isMobile ? 16 : 20),
          
          // Stats/Features grid
          isSmallScreen
              ? Column(
                  children: [
                    _buildFeatureCard(
                      iconName: ClovaraIcons.bolt,
                      title: 'Lightning Fast',
                      description: 'AI quotes in 2 minutes',
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureCard(
                      iconName: ClovaraIcons.shieldCheck,
                      title: 'Full Coverage',
                      description: '90-95% reimbursement',
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureCard(
                      icon: Icons.check_circle_outline,
                      title: 'Instant Decisions',
                      description: 'Auto-approved claims',
                      isMobile: isMobile,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _buildFeatureCard(
                        iconName: ClovaraIcons.bolt,
                        title: 'Lightning Fast',
                        description: 'AI quotes in 2 minutes',
                        isMobile: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _buildFeatureCard(
                        iconName: ClovaraIcons.shieldCheck,
                        title: 'Full Coverage',
                        description: '90-95% reimbursement',
                        isMobile: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _buildFeatureCard(
                        icon: Icons.check_circle_outline,
                        title: 'Instant Decisions',
                        description: 'Auto-approved claims',
                        isMobile: false,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  /// Individual feature card
  Widget _buildFeatureCard({
    IconData? icon,
    String? iconName,
    required String title,
    required String description,
    required bool isMobile,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : 260,
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ClovaraColors.clover.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconName != null
              ? ClovaraIcon(
                  iconName,
                  size: isMobile ? 28 : 32,
                  color: ClovaraColors.sunset,
                )
              : Icon(
                  icon,
                  size: isMobile ? 28 : 32,
                  color: ClovaraColors.sunset,
                ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: ClovaraTypography.label.copyWith(
                    color: ClovaraColors.forest,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.slate,
                    fontSize: isMobile ? 12 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact footer
  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          Text(
            "© 2025 Clovara",
            style: ClovaraTypography.bodySmall.copyWith(
              color: ClovaraColors.slate.withOpacity(0.7),
              fontSize: isMobile ? 11 : 12,
            ),
          ),
          Text(
            '•',
            style: ClovaraTypography.bodySmall.copyWith(
              color: ClovaraColors.slate.withOpacity(0.5),
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'Terms',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.sunset,
                fontSize: isMobile ? 11 : 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '•',
            style: ClovaraTypography.bodySmall.copyWith(
              color: ClovaraColors.slate.withOpacity(0.5),
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'Privacy',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.sunset,
                fontSize: isMobile ? 11 : 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '•',
            style: ClovaraTypography.bodySmall.copyWith(
              color: ClovaraColors.slate.withOpacity(0.5),
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'Contact',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.sunset,
                fontSize: isMobile ? 11 : 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

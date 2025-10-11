import 'package:flutter/material.dart';
import '../theme/petuwrite_theme.dart';

/// PetUwrite Homepage - Landing page with navigation options
/// 
/// Features:
/// - Navy background with logo
/// - 3 action cards: Get Quote, File Claim, Sign In
/// - Responsive design
/// - Brand-consistent styling
class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: PetUwriteColors.kPrimaryNavy,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 32.0 : 64.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Company Name at top
                  const SizedBox(height: 20),
                  Text(
                    'PetUwrite',
                    style: PetUwriteTypography.h1.copyWith(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Compact Logo Section
                  const SizedBox(height: 8),
                  _buildLogoSection(context, isSmallScreen),
                  
                  const SizedBox(height: 40),
                  
                  // Action Cards Grid
                  _buildActionCards(context, isSmallScreen),
                  
                  const SizedBox(height: 40),
                  
                  // Features/Stats Section
                  _buildFeaturesSection(context, isSmallScreen),
                  
                  const SizedBox(height: 32),
                  
                  // Footer
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Large centered logo section
  Widget _buildLogoSection(BuildContext context, bool isSmallScreen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Large logo image (icon only, no text)
        Container(
          width: isSmallScreen ? 200 : 280,
          height: isSmallScreen ? 200 : 280,
          child: Image.asset(
            'assets/PetUwrite icon only.png',
            fit: BoxFit.contain,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tagline only (no app name)
        Text(
          PetUwriteAssets.tagline,
          style: PetUwriteTypography.bodyLarge.copyWith(
            color: PetUwriteColors.kAccentSky,
            fontStyle: FontStyle.italic,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Action cards in grid layout
  Widget _buildActionCards(BuildContext context, bool isSmallScreen) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: isSmallScreen
          ? Column(
              children: [
                _buildActionCard(
                  context: context,
                  icon: Icons.pets,
                  title: 'Get a Quote',
                  subtitle: 'AI-powered quotes in minutes',
                  gradient: const LinearGradient(
                    colors: [PetUwriteColors.kSecondaryTeal, Color(0xFF008B94)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/conversational-quote'),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context: context,
                  icon: Icons.medical_services_outlined,
                  title: 'File a Claim',
                  subtitle: 'Quick claims submission',
                  gradient: LinearGradient(
                    colors: [
                      PetUwriteColors.kAccentSky.withOpacity(0.9),
                      PetUwriteColors.kSecondaryTeal.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claims feature coming soon!'),
                        backgroundColor: PetUwriteColors.kSecondaryTeal,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context: context,
                  icon: Icons.account_circle_outlined,
                  title: 'Sign In',
                  subtitle: 'Access your account',
                  gradient: const LinearGradient(
                    colors: [PetUwriteColors.kSecondaryTeal, Color(0xFF008B94)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/auth-gate'),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.pets,
                    title: 'Get a Quote',
                    subtitle: 'AI-powered insurance quotes in minutes',
                    gradient: const LinearGradient(
                      colors: [PetUwriteColors.kSecondaryTeal, Color(0xFF008B94)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/conversational-quote'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.medical_services_outlined,
                    title: 'File a Claim',
                    subtitle: 'Quick and easy claims submission',
                    gradient: LinearGradient(
                      colors: [
                        PetUwriteColors.kAccentSky.withOpacity(0.9),
                        PetUwriteColors.kSecondaryTeal.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Claims feature coming soon!'),
                          backgroundColor: PetUwriteColors.kSecondaryTeal,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    title: 'Sign In',
                    subtitle: 'Access your policies and account',
                    gradient: const LinearGradient(
                      colors: [PetUwriteColors.kSecondaryTeal, Color(0xFF008B94)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/auth-gate'),
                  ),
                ),
              ],
            ),
    );
  }

  /// Compact action card widget
  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  title,
                  style: PetUwriteTypography.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  subtitle,
                  style: PetUwriteTypography.body.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Arrow indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Features/Stats section to fill space
  Widget _buildFeaturesSection(BuildContext context, bool isSmallScreen) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        children: [
          // Section title
          Text(
            'Why Choose PetUwrite?',
            style: PetUwriteTypography.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Stats/Features grid
          isSmallScreen
              ? Column(
                  children: [
                    _buildFeatureCard(
                      icon: Icons.speed,
                      title: 'Instant Quotes',
                      description: 'Get AI-powered quotes in under 2 minutes',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.shield_outlined,
                      title: 'Comprehensive Coverage',
                      description: 'Protect your pet with 90-95% reimbursement',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.psychology_outlined,
                      title: 'AI-Powered',
                      description: 'Smart underwriting for accurate pricing',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Trusted Platform',
                      description: 'Secure and transparent insurance process',
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.speed,
                        title: 'Instant Quotes',
                        description: 'Get AI-powered quotes in under 2 minutes',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.shield_outlined,
                        title: 'Comprehensive Coverage',
                        description: 'Protect your pet with 90-95% reimbursement',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.psychology_outlined,
                        title: 'AI-Powered',
                        description: 'Smart underwriting for accurate pricing',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.verified_user_outlined,
                        title: 'Trusted Platform',
                        description: 'Secure and transparent insurance process',
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
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      height: 160, // Fixed height for all cards
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PetUwriteColors.kAccentSky.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 36,
            color: PetUwriteColors.kSecondaryTeal,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: PetUwriteTypography.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: PetUwriteTypography.caption.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Compact footer
  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // Copyright and links in one line
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Text(
              PetUwriteAssets.copyright,
              style: PetUwriteTypography.caption.copyWith(
                color: PetUwriteColors.kTextMuted,
                fontSize: 11,
              ),
            ),
            Text(
              '•',
              style: PetUwriteTypography.caption.copyWith(
                color: PetUwriteColors.kTextMuted,
              ),
            ),
            InkWell(
              onTap: () {},
              child: Text(
                'Terms',
                style: PetUwriteTypography.caption.copyWith(
                  color: PetUwriteColors.kAccentSky,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '•',
              style: PetUwriteTypography.caption.copyWith(
                color: PetUwriteColors.kTextMuted,
              ),
            ),
            InkWell(
              onTap: () {},
              child: Text(
                'Privacy',
                style: PetUwriteTypography.caption.copyWith(
                  color: PetUwriteColors.kAccentSky,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '•',
              style: PetUwriteTypography.caption.copyWith(
                color: PetUwriteColors.kTextMuted,
              ),
            ),
            InkWell(
              onTap: () {},
              child: Text(
                'Contact',
                style: PetUwriteTypography.caption.copyWith(
                  color: PetUwriteColors.kAccentSky,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

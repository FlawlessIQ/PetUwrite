import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/clovara_theme.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../services/user_session_service.dart';
import '../services/draft_service.dart';
import 'underwriting_followup_documents_screen.dart';
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header with logo
                    _buildHeader(context, isMobile),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 40,
                        vertical: 24,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tagline
                            _buildTagline(context, isMobile),
                            
                            SizedBox(height: isMobile ? 32 : 48),

                            // Resume via server-side Draft (cross-device)
                            _buildDraftResumeCard(context, isMobile),

                            if (isMobile)
                              const SizedBox(height: 12)
                            else
                              const SizedBox(height: 16),

                            // Resume underwriting (NEED_MORE_INFO) if available
                            _buildResumeUnderwritingCard(context, isMobile),

                            if (isMobile)
                              const SizedBox(height: 12)
                            else
                              const SizedBox(height: 16),
                            
                            // Action Cards
                            _buildActionCards(context, isSmallScreen, isMobile),
                            
                            SizedBox(height: isMobile ? 32 : 48),
                            
                            // Features
                            _buildFeaturesSection(context, isSmallScreen, isMobile),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
                    _buildFooter(context, isMobile),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDraftResumeCard(BuildContext context, bool isMobile) {
    return FutureBuilder<String?>(
      future: DraftService().getLocalResumeKey(),
      builder: (context, snapshot) {
        final localKey = snapshot.data;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ClovaraColors.mist,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.restore,
                    color: ClovaraColors.forest,
                    size: isMobile ? 20 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue where you left off',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resume on this device, or enter a resume code',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.slate,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (localKey != null)
                  ElevatedButton(
                    onPressed: () => _resumeFromKey(context, localKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClovaraColors.clover,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 16,
                        vertical: isMobile ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _showResumeCodeDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClovaraColors.forest,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 16,
                        vertical: isMobile ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enter code'),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Enter resume code',
                  onPressed: () => _showResumeCodeDialog(context),
                  icon: const Icon(Icons.key),
                  color: ClovaraColors.slate,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showResumeCodeDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resume with code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste your resume code',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final text = (data?.text ?? '').trim();
                if (text.isNotEmpty) controller.text = text;
              },
              child: const Text('Paste'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = controller.text.trim();
                Navigator.pop(context);
                if (key.isNotEmpty) {
                  _resumeFromKey(context, key);
                }
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resumeFromKey(BuildContext context, String resumeKey) async {
    // Lightweight blocking progress UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 72,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Resuming…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resolved = await DraftService().resolveAndAdoptDraft(
        resumeKey: resumeKey,
      );

      // Restore local pending state so existing screens keep working.
      if (resolved.draftType == 'quote') {
        await UserSessionService().savePendingQuote(resolved.snapshot);
      } else if (resolved.draftType == 'checkout') {
        await UserSessionService().savePendingCheckout(resolved.snapshot);
      } else {
        final caseId = resolved.snapshot['underwritingCaseId']?.toString();
        if (caseId != null && caseId.trim().isNotEmpty) {
          await UserSessionService().savePendingUnderwriting(
            underwritingCaseId: caseId.trim(),
            petName: (resolved.snapshot['petName'] ?? 'your pet').toString(),
            riskScore: resolved.snapshot['riskScore'],
            reason: resolved.snapshot['reason']?.toString(),
            requiredEvidence:
                (resolved.snapshot['requiredEvidence'] is List)
                    ? (resolved.snapshot['requiredEvidence'] as List)
                        .whereType<Map>()
                        .map((e) => e.cast<String, dynamic>())
                        .toList(growable: false)
                    : const [],
          );
        }
      }

      if (context.mounted) Navigator.pop(context);

      if (resolved.draftType == 'quote') {
        if (context.mounted) {
          context.push('/conversational-quote');
        }
        return;
      }

      if (resolved.draftType == 'checkout') {
        final pet = resolved.snapshot['pet'];
        final selectedPlan = resolved.snapshot['selectedPlan'];
        if (pet != null && selectedPlan != null) {
          if (context.mounted) {
            context.push(
              '/checkout',
              extra: {
                'pet': pet,
                'selectedPlan': selectedPlan,
                'underwritingCaseId':
                    resolved.snapshot['underwritingCaseId']?.toString(),
                'exclusions': resolved.snapshot['exclusions'],
                'underwritingSnapshot':
                    resolved.snapshot['underwritingSnapshot'],
              },
            );
          }
          return;
        }
      }

      final caseId = resolved.snapshot['underwritingCaseId']?.toString();
      if (caseId != null && caseId.trim().isNotEmpty) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnderwritingFollowUpDocumentsScreen(
                underwritingCaseId: caseId.trim(),
              ),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft restored, but nothing to resume.')),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to resume: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  Widget _buildResumeUnderwritingCard(BuildContext context, bool isMobile) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserSessionService().getPendingUnderwriting(),
      builder: (context, snapshot) {
        final pending = snapshot.data;
        final caseId = pending?['underwritingCaseId']?.toString().trim();
        if (caseId == null || caseId.isEmpty) {
          return const SizedBox.shrink();
        }

        final petName = pending?['petName']?.toString().trim();

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            decoration: BoxDecoration(
              color: ClovaraColors.mist,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ClovaraColors.clover.withOpacity(0.25),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.upload_file_outlined,
                    color: ClovaraColors.forest,
                    size: isMobile ? 20 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finish underwriting',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        petName != null && petName.isNotEmpty
                            ? 'Upload documents for $petName'
                            : 'Upload documents to continue',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.slate,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const UnderwritingFollowUpDocumentsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClovaraColors.clover,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 16,
                      vertical: isMobile ? 10 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
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
                  onTap: () => context.push('/conversational-quote'),
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
                    onTap: () => context.push('/conversational-quote'),
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

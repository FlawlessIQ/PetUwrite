import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/tokens.dart';
import '../screens/conversational_quote_flow.dart';
import '../screens/claims/claim_intake_screen.dart';
import '../screens/claims/claim_details_screen.dart';
import '../screens/claims/claims_list_screen.dart';
import '../screens/underwriting_followup_documents_screen.dart';
import '../services/user_session_service.dart';
import '../services/underwriting_case_service.dart';

/// Modern Clovara Customer Dashboard
/// Clean white background with gradient accent cards
class CustomerHomeScreen extends StatefulWidget {
  final bool isPremium;

  const CustomerHomeScreen({
    super.key,
    this.isPremium = false,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final horizontalPadding = isMobile ? 18.0 : 28.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero (header + welcome + stats)
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.auroraGradient,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMobile ? 16 : 22,
                    horizontalPadding,
                    18,
                  ),
                  child: MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, user, isMobile),
                        const SizedBox(height: 12),
                        _buildWelcomeMessage(user, isMobile),
                        const SizedBox(height: 16),
                        _buildQuickStats(user, isMobile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Pending Quotes Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: MaxWidth(
                  child: _buildPendingQuotesSection(context, user, isMobile),
                ),
              ),
            ),

            // Underwriting Follow-up (Documents Needed)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 6,
                ),
                child: MaxWidth(
                  child: _buildPendingUnderwritingSection(
                    context,
                    user,
                    isMobile,
                  ),
                ),
              ),
            ),
            
            // Active Policies Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 6,
                ),
                child: MaxWidth(
                  child: _buildPoliciesSection(context, user, isMobile),
                ),
              ),
            ),
            
            // Recent Claims Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 6,
                ),
                child: MaxWidth(
                  child: _buildRecentClaimsSection(context, user, isMobile),
                ),
              ),
            ),
            
            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: MaxWidth(child: _buildQuickActions(context, isMobile)),
              ),
            ),
            
            // Bottom Padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, bool isMobile) {
    return Row(
      children: [
        ClovaraLogoLockup(
          markSize: isMobile ? 34 : 38,
          textSize: isMobile ? 22 : 24,
        ),
        const Spacer(),
        Tooltip(
          message: 'Sign out',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _handleSignOut(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.deepGreen,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage(User? user, bool isMobile) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w800,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          height: 1.3,
        );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br24,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back! 👋', style: titleStyle),
          const SizedBox(height: 6),
          Text(user?.email ?? 'Customer', style: subtitleStyle),
        ],
      ),
    );
  }

  Widget _buildQuickStats(User? user, bool isMobile) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final policies = snapshot.data?.docs ?? [];
        final uniquePets = <String>{};
        
        for (final doc in policies) {
          final data = doc.data() as Map<String, dynamic>;
          final petData = data['pet'] as Map<String, dynamic>?;
          if (petData != null && petData['id'] != null) {
            uniquePets.add(petData['id']);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 560;
            final children = [
              _buildStatCard(
                icon: Icons.pets,
                count: uniquePets.length.toString(),
                label: 'Pets',
                isMobile: isMobile,
              ),
              _buildStatCard(
                icon: Icons.description_outlined,
                count: policies.length.toString(),
                label: 'Policies',
                isMobile: isMobile,
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 12),
                  children[1],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 12),
                Expanded(child: children[1]),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String count,
    required String label,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br24,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.deepGreen,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingQuotesSection(BuildContext context, User? user, bool isMobile) {
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: UserSessionService().getUserPendingQuotes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingQuotes = snapshot.data!;

        return _PortalSection(
          title: 'Continue',
          subtitle: 'Pick up where you left off.',
          child: Column(
            children: pendingQuotes
                .map((quote) => _buildPendingQuoteCard(context, quote, isMobile))
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildPendingUnderwritingSection(
    BuildContext context,
    User? user,
    bool isMobile,
  ) {
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserSessionService().getPendingUnderwriting(),
      builder: (context, snapshot) {
        final pending = snapshot.data;
        final caseId = pending?['underwritingCaseId']?.toString().trim();
        if (caseId == null || caseId.isEmpty) {
          return const SizedBox.shrink();
        }

        final petName = pending?['petName']?.toString().trim();

        return FutureBuilder(
          future: UnderwritingCaseService().getCase(caseId),
          builder: (context, caseSnap) {
            final uwCase = caseSnap.data;

            // If the saved underwriting is for a different account, do not
            // offer a resume path on the signed-in dashboard.
            final belongsToUser = uwCase != null && uwCase.userId == user.uid;

            return Padding(
              padding: EdgeInsets.zero,
              child: _PortalSection(
                title: 'Documents needed',
                subtitle: 'Upload follow-ups to continue underwriting.',
                trailing: TextButton(
                  onPressed: () async {
                    await UserSessionService().clearPendingUnderwriting();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saved underwriting cleared.'),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: const Text('Clear'),
                ),
                child: _PortalListItem(
                  enabled: belongsToUser,
                  leading: Icons.upload_file_outlined,
                  title: belongsToUser
                      ? 'Continue underwriting'
                      : 'Saved underwriting found',
                  subtitle: belongsToUser
                      ? (petName != null && petName.isNotEmpty
                          ? 'Upload follow-up documents for $petName'
                          : 'Upload follow-up documents to continue')
                      : 'This saved case belongs to a different account on this device.',
                  onTap: belongsToUser
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UnderwritingFollowUpDocumentsScreen(),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingQuoteCard(
      BuildContext context, Map<String, dynamic> quote, bool isMobile) {
    final quoteData = quote['quoteData'] as Map<String, dynamic>?;
    final answers = quoteData?['answers'] as Map<String, dynamic>?;
    final petName = answers?['petName'] as String?;
    final quoteId = quote['id'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PortalListItem(
        leading: Icons.pending_outlined,
        title: petName != null ? 'Quote for $petName' : 'Pet insurance quote',
        subtitle: 'Tap to continue',
        onTap: () => _resumePendingQuote(context, quoteId),
      ),
    );
  }

  Widget _buildPoliciesSection(BuildContext context, User? user, bool isMobile) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final policies = snapshot.data!.docs;

        return _PortalSection(
          title: 'My policies',
          subtitle: 'Your active coverage at a glance.',
          child: Column(
            children: policies.take(2).map((policy) {
              final data = policy.data() as Map<String, dynamic>;
              return _buildPolicyCard(context, data, isMobile);
            }).toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildPolicyCard(
      BuildContext context, Map<String, dynamic> policy, bool isMobile) {
    final petData = policy['pet'] as Map<String, dynamic>?;
    final petName = petData?['name'] as String? ?? 'Pet';
    final planData = policy['plan'] as Map<String, dynamic>?;
    final planName = planData?['name'] as String? ?? 'Policy';
    final monthlyPremium = planData?['monthlyPremium'] as num?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PortalListItem(
        leading: Icons.description_outlined,
        title: petName,
        subtitle: planName,
        trailing: monthlyPremium == null
            ? null
            : Text(
                '\$${monthlyPremium.toStringAsFixed(0)}/mo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
              ),
      ),
    );
  }

  Widget _buildRecentClaimsSection(BuildContext context, User? user, bool isMobile) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final claims = snapshot.data!.docs;

        return _PortalSection(
          title: 'Recent claims',
          subtitle: 'Updates on reimbursements and decisions.',
          trailing: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClaimsListScreen(),
                ),
              );
            },
            child: const Text('View all'),
          ),
          child: Column(
            children: claims
                .map((claim) => _buildClaimCard(context, claim, isMobile))
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildClaimCard(
      BuildContext context, QueryDocumentSnapshot claimDoc, bool isMobile) {
    final claim = claimDoc.data() as Map<String, dynamic>;
    final claimType = claim['claimType'] as String? ?? 'Claim';
    final status = claim['status'] as String? ?? 'pending';
    final amount = (claim['claimAmount'] as num?)?.toDouble() ?? 0.0;

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'settled':
      case 'approved':
      case 'settling':
        statusColor = AppColors.success;
        break;
      case 'denied':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.warning;
    }

    final statusLabel = status.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PortalListItem(
        leading: (status.toLowerCase() == 'settled' ||
                status.toLowerCase() == 'approved')
            ? Icons.check_circle
            : (status.toLowerCase() == 'settling')
                ? Icons.payments
                : Icons.pending,
        leadingColor: statusColor,
        title: claimType,
        subtitle: statusLabel,
        trailing: amount > 0
            ? Text(
                '\$${amount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w800,
                    ),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClaimDetailsScreen(claimId: claimDoc.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isMobile) {
    final actions = [
      {
        'icon': Icons.add_circle_outline,
        'title': 'Get a Quote',
        'subtitle': 'AI-powered quotes',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConversationalQuoteFlow(),
              ),
            ),
      },
      {
        'icon': Icons.medical_services_outlined,
        'title': 'File a Claim',
        'subtitle': 'Quick submission',
        'onTap': () => _handleFileClaim(context),
      },
      {
        'icon': Icons.help_outline,
        'title': 'Help & Support',
        'subtitle': 'Get assistance',
        'onTap': () => _showHelpDialog(context),
      },
    ];

    return _PortalSection(
      title: 'Quick actions',
      subtitle: 'Start a quote, file a claim, or get support.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980 ? 3 : (constraints.maxWidth >= 640 ? 2 : 1);
          final itemWidth = (constraints.maxWidth - (12 * (columns - 1))) / columns;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map(
                  (action) => SizedBox(
                    width: itemWidth,
                    child: _PortalActionCard(
                      icon: action['icon'] as IconData,
                      title: action['title'] as String,
                      subtitle: action['subtitle'] as String,
                      onTap: action['onTap'] as VoidCallback,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  // Helper Methods

  Future<void> _resumePendingQuote(BuildContext context, String quoteId) async {
    try {
      await UserSessionService().resumePendingQuote(quoteId);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ConversationalQuoteFlow(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming quote: $e')),
        );
      }
    }
  }

  void _handleFileClaim(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user's policies
    final policiesSnapshot = await FirebaseFirestore.instance
        .collection('policies')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    if (policiesSnapshot.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need an active policy to file a claim'),
          ),
        );
      }
      return;
    }

    // Use first policy
    final policy = policiesSnapshot.docs.first.data();
    final petData = policy['pet'] as Map<String, dynamic>?;
    final petId = petData?['id'] as String?;
    final policyId = policiesSnapshot.docs.first.id;

    if (petId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClaimIntakeScreen(
            policyId: policyId,
            petId: petId,
          ),
        ),
      );
    }
  }

  void _handleSignOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    context.go('/');
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'Need help? Contact us at:\n\n'
          'Email: support@clovara.com\n'
          'Phone: 1-800-CLOVARA',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PortalSection extends StatelessWidget {
  const _PortalSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w800,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          height: 1.35,
          fontWeight: FontWeight.w600,
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br24,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PortalListItem extends StatelessWidget {
  const _PortalListItem({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.leadingColor,
  });

  final IconData leading;
  final Color? leadingColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: enabled ? AppColors.deepGreen : AppColors.textSubtle,
          fontWeight: FontWeight.w800,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: enabled ? AppColors.textMuted : AppColors.textSubtle,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.br20,
      child: InkWell(
        borderRadius: AppRadii.br20,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.br20,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  leading,
                  color: leadingColor ?? AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: subtitleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ] else ...[
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: AppColors.textSubtle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalActionCard extends StatelessWidget {
  const _PortalActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w800,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          height: 1.3,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.br24,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.br24,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadii.br24,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 6),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: AppColors.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

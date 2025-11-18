import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/clovara_theme.dart';
import '../screens/conversational_quote_flow.dart';
import '../screens/claims/claim_intake_screen.dart';
import '../services/user_session_service.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Modern Header
            SliverToBoxAdapter(
              child: _buildHeader(context, user, isMobile),
            ),
            
            // Welcome Message
            SliverToBoxAdapter(
              child: _buildWelcomeMessage(user, isMobile),
            ),
            
            // Quick Stats
            SliverToBoxAdapter(
              child: _buildQuickStats(user, isMobile),
            ),
            
            // Pending Quotes Section
            SliverToBoxAdapter(
              child: _buildPendingQuotesSection(context, user, isMobile),
            ),
            
            // Active Policies Section
            SliverToBoxAdapter(
              child: _buildPoliciesSection(context, user, isMobile),
            ),
            
            // Recent Claims Section
            SliverToBoxAdapter(
              child: _buildRecentClaimsSection(context, user, isMobile),
            ),
            
            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(context, isMobile),
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
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
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
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
            ),
          ),
          const SizedBox(width: 16),
          // Brand name
          Expanded(
            child: Text(
              'Clovara',
              style: ClovaraTypography.h1.copyWith(
                color: ClovaraColors.forest,
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ),
          // Sign Out Button
          IconButton(
            onPressed: () => _handleSignOut(context),
            icon: const Icon(Icons.logout),
            color: ClovaraColors.slate,
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(User? user, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back! 👋',
            style: ClovaraTypography.h2.copyWith(
              color: ClovaraColors.forest,
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? 'Customer',
            style: ClovaraTypography.body.copyWith(
              color: ClovaraColors.slate,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
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

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pets,
                  count: uniquePets.length.toString(),
                  label: 'Pets',
                  isMobile: isMobile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.description_outlined,
                  count: policies.length.toString(),
                  label: 'Policies',
                  isMobile: isMobile,
                ),
              ),
            ],
          ),
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
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClovaraColors.clover.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: ClovaraColors.clover,
            size: isMobile ? 24 : 28,
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: ClovaraTypography.h2.copyWith(
              color: ClovaraColors.forest,
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: ClovaraTypography.body.copyWith(
              color: ClovaraColors.slate,
              fontSize: isMobile ? 12 : 14,
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

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue Your Quote',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 24,
                ),
              ),
              const SizedBox(height: 12),
              ...pendingQuotes.map((quote) =>
                  _buildPendingQuoteCard(context, quote, isMobile)),
            ],
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ClovaraColors.clover,
            Color(0xFF7CB342),
            ClovaraColors.sunset,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _resumePendingQuote(context, quoteId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pending_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName != null ? 'Quote for $petName' : 'Pet Insurance Quote',
                        style: ClovaraTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 16 : 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to continue',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Policies',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 24,
                ),
              ),
              const SizedBox(height: 12),
              ...policies.take(2).map((policy) {
                final data = policy.data() as Map<String, dynamic>;
                return _buildPolicyCard(context, data, isMobile);
              }),
            ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClovaraColors.clover.withOpacity(0.3),
        ),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description,
                  color: ClovaraColors.clover,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 16 : 18,
                      ),
                    ),
                    Text(
                      planName,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (monthlyPremium != null)
                Text(
                  '\$${monthlyPremium.toStringAsFixed(0)}/mo',
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.clover,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
            ],
          ),
        ],
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

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Claims',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 24,
                ),
              ),
              const SizedBox(height: 12),
              ...claims.map((claim) {
                final data = claim.data() as Map<String, dynamic>;
                return _buildClaimCard(context, data, isMobile);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimCard(
      BuildContext context, Map<String, dynamic> claim, bool isMobile) {
    final claimType = claim['claimType'] as String? ?? 'Claim';
    final status = claim['status'] as String? ?? 'pending';
    final amount = (claim['claimAmount'] as num?)?.toDouble() ?? 0.0;

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'settled':
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'denied':
        statusColor = Colors.red;
        break;
      default:
        statusColor = ClovaraColors.sunset;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status.toLowerCase() == 'settled' || status.toLowerCase() == 'approved'
                  ? Icons.check_circle
                  : Icons.pending,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claimType,
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: statusColor,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (amount > 0)
            Text(
              '\$${amount.toStringAsFixed(0)}',
              style: ClovaraTypography.body.copyWith(
                color: ClovaraColors.forest,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 16 : 18,
              ),
            ),
        ],
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 18 : 24,
            ),
          ),
          const SizedBox(height: 12),
          ...actions.map((action) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      ClovaraColors.clover,
                      Color(0xFF7CB342),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ClovaraColors.clover.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action['onTap'] as VoidCallback,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              action['icon'] as IconData,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action['title'] as String,
                                  style: ClovaraTypography.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 16 : 18,
                                  ),
                                ),
                                Text(
                                  action['subtitle'] as String,
                                  style: ClovaraTypography.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
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
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
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

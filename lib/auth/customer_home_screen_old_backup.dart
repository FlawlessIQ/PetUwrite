import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/quote_flow_screen.dart';
import '../theme/clovara_theme.dart';
import '../screens/conversational_quote_flow.dart';
import '../screens/claims/claim_intake_screen.dart';
import '../services/user_session_service.dart';
import '../services/claims_service.dart';
import '../services/claim_decision_engine.dart';
import '../models/claim.dart';

/// PetUwrite Customer Dashboard - Premium, modern UI
/// World-class design with glassmorphism, animations, and brand aesthetics
class CustomerHomeScreen extends StatefulWidget {
  final bool isPremium;

  const CustomerHomeScreen({
    super.key,
    this.isPremium = false,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Sync pets from policies to users/{uid}/pets collection
    _syncPetsFromPolicies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Sync pets from policies to users/{uid}/pets collection for backwards compatibility
  Future<void> _syncPetsFromPolicies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all policies for this user
      final policiesSnapshot = await FirebaseFirestore.instance
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      // Extract unique pets from policies
      final uniquePets = <String, Map<String, dynamic>>{};
      for (final doc in policiesSnapshot.docs) {
        final policyData = doc.data();
        final petData = policyData['pet'] as Map<String, dynamic>?;
        if (petData != null && petData['id'] != null) {
          uniquePets[petData['id']] = petData;
        }
      }

      // Check if pets already exist in users/{uid}/pets
      final userPetsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets');

      final existingPetsSnapshot = await userPetsRef.get();
      final existingPetIds = existingPetsSnapshot.docs.map((doc) => doc.id).toSet();

      // Add missing pets to users/{uid}/pets collection
      for (final entry in uniquePets.entries) {
        final petId = entry.key;
        final petData = entry.value;
        
        if (!existingPetIds.contains(petId)) {
          await userPetsRef.doc(petId).set({
            ...petData,
            'ownerId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'policy_sync', // Mark as synced from policy
          });
        }
      }
    } catch (e) {
      print('Error syncing pets from policies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: ClovaraColors.forest,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('policies')
            .where('ownerId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, policiesSnapshot) {
          // Extract unique pets from policies
          final uniquePets = <String, Map<String, dynamic>>{};
          final policies = policiesSnapshot.data?.docs ?? [];
          
          for (final doc in policies) {
            final policyData = doc.data() as Map<String, dynamic>;
            final petData = policyData['pet'] as Map<String, dynamic>?;
            if (petData != null && petData['id'] != null) {
              uniquePets[petData['id']] = petData;
            }
          }
          
          final petCount = uniquePets.length;
          final policyCount = policies.length;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                // Main content
                SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Curved Header
                      SliverToBoxAdapter(
                        child: _buildCurvedHeader(context, user),
                      ),
                      // Stats Section
                      SliverToBoxAdapter(
                        child: _buildStatsSection(petCount, policyCount),
                      ),
                      // Pending Quotes Section
                      SliverToBoxAdapter(
                        child: _buildPendingQuotesSection(context, user),
                      ),
                      // Active Policies Section
                      SliverToBoxAdapter(
                        child: _buildActivePoliciesSection(context, user, policies),
                      ),
                      // Pending Claims Section
                      SliverToBoxAdapter(
                        child: _buildPendingClaimsSection(context, user),
                      ),
                      // Recent Claims Section (shows all claims including completed)
                      SliverToBoxAdapter(
                        child: _buildRecentClaimsSection(context, user),
                      ),
                      // Action Grid
                      SliverToBoxAdapter(
                        child: _buildActionGrid(context, uniquePets.values.toList()),
                      ),
                      // Quick Links Carousel
                      SliverToBoxAdapter(
                        child: _buildQuickLinksCarousel(context),
                      ),
                      // Bottom Padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurvedHeader(BuildContext context, User? user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Stack(
        children: [
          // Curved background with gradient
          ClipPath(
            clipper: _CurvedHeaderClipper(),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ClovaraColors.forest,
                    ClovaraColors.clover.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          // Header content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Company Logo with glassmorphism
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: SvgPicture.asset(
                              'assets/images/clovara_mark_refined.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back! 👋',
                            style: ClovaraTypography.h3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Customer',
                            style: ClovaraTypography.body.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Premium Badge & Profile
                    if (widget.isPremium) ...[
                      _PremiumBadge(),
                      const SizedBox(width: 8),
                    ],
                    _ProfileButton(onPressed: () => _showProfileDialog(context)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int petCount, int policyCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _AnimatedStatCard(
                      icon: Icons.pets,
                      count: petCount.toString(),
                      label: 'Pets',
                      gradient: LinearGradient(
                        colors: [
                          ClovaraColors.kSuccessMint.withOpacity(0.8),
                          ClovaraColors.kSuccessMint,
                        ],
                      ),
                      delay: Duration.zero,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _AnimatedStatCard(
                      icon: Icons.description_outlined,
                      count: policyCount.toString(),
                      label: 'Policies',
                      gradient: LinearGradient(
                        colors: [
                          ClovaraColors.sunset.withOpacity(0.8),
                          ClovaraColors.sunset,
                        ],
                      ),
                      delay: const Duration(milliseconds: 100),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _AnimatedStatCard(
                      icon: Icons.medical_services_outlined,
                      count: '0',
                      label: 'Claims',
                      gradient: LinearGradient(
                        colors: [
                          ClovaraColors.kWarmCoral.withOpacity(0.8),
                          ClovaraColors.kWarmCoral,
                        ],
                      ),
                      delay: const Duration(milliseconds: 200),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingQuotesSection(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: UserSessionService().getUserPendingQuotes(),
      builder: (context, snapshot) {
        // Don't show anything while loading or if no pending quotes
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final pendingQuotes = snapshot.data ?? [];
        if (pendingQuotes.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue Your Quote',
                style: ClovaraTypography.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...pendingQuotes.map((quote) => _buildPendingQuoteCard(context, quote)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingQuoteCard(BuildContext context, Map<String, dynamic> quote) {
    final quoteData = quote['quoteData'] as Map<String, dynamic>?;
    final answers = quoteData?['answers'] as Map<String, dynamic>?;
    final petName = answers?['petName'] as String?;
    final createdAt = quote['createdAt'] as Timestamp?;
    final quoteId = quote['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClovaraColors.clover.withOpacity(0.3),
            ClovaraColors.clover.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pending_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName != null ? 'Quote for $petName' : 'Pet Insurance Quote',
                        style: ClovaraTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt != null
                            ? 'Started ${_formatTimestamp(createdAt)}'
                            : 'In progress',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Resume button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _resumePendingQuote(context, quoteId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _deletePendingQuote(context, quoteId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white.withOpacity(0.7),
                            size: 24,
                          ),
                        ),
                      ),
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _resumePendingQuote(BuildContext context, String quoteId) async {
    try {
      // Resume the quote - navigate to the quote flow
      // The quote flow will automatically restore the pending quote
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

  Future<void> _deletePendingQuote(BuildContext context, String quoteId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote?'),
        content: const Text('Are you sure you want to delete this pending quote? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quoteId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quote deleted successfully')),
          );
          // Refresh the screen
          setState(() {});
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting quote: $e')),
          );
        }
      }
    }
  }

  Widget _buildActivePoliciesSection(BuildContext context, User? user, List<QueryDocumentSnapshot> policies) {
    if (user == null || policies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Policies',
                style: ClovaraTypography.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (policies.length > 1)
                TextButton(
                  onPressed: () => _showPoliciesScreen(context),
                  child: Text(
                    'View All',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.clover,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Show first policy or up to 2 policies
          ...policies.take(2).map((policy) => _buildPolicyCard(context, policy.data() as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, Map<String, dynamic> policy) {
    final policyNumber = policy['policyNumber'] as String?;
    final petData = policy['pet'] as Map<String, dynamic>?;
    final petName = petData?['name'] as String?;
    final planData = policy['plan'] as Map<String, dynamic>?;
    final planName = planData?['name'] as String?;
    final monthlyPremium = planData?['monthlyPremium'] as num?;
    final status = policy['status'] as String? ?? 'unknown';
    final expirationDate = policy['expirationDate'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPolicyStatusColor(status).withOpacity(0.3),
            _getPolicyStatusColor(status).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Policy Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getPolicyStatusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Policy Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policyNumber != null ? 'Policy #$policyNumber' : 'Policy Document',
                            style: ClovaraTypography.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            petName != null ? 'Pet: $petName' : 'Pet Insurance Policy',
                            style: ClovaraTypography.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          if (planName != null)
                            Text(
                              planName,
                              style: ClovaraTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPolicyStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatPolicyStatus(status),
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Policy Details Row
                Row(
                  children: [
                    if (monthlyPremium != null) ...[
                      Icon(Icons.attach_money, color: Colors.white.withOpacity(0.8), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '\$${monthlyPremium.toStringAsFixed(2)}/month',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (expirationDate != null) ...[
                      Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Expires ${_formatPolicyDate(expirationDate)}',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showPolicyDetails(context, policy),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadPolicyPDF(context, policy),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClovaraColors.clover.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
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

  Color _getPolicyStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return ClovaraColors.clover;
      case 'expired':
        return ClovaraColors.kWarmCoral;
      case 'cancelled':
        return Colors.grey;
      default:
        return ClovaraColors.sunset;
    }
  }

  String _formatPolicyStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'pending':
        return 'PENDING';
      case 'expired':
        return 'EXPIRED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  String _formatPolicyDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = date.difference(now);
      
      if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return 'in $months months';
      } else if (difference.inDays > 0) {
        return 'in ${difference.inDays} days';
      } else if (difference.inDays == 0) {
        return 'today';
      } else {
        return '${(-difference.inDays)} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _downloadPolicyPDF(BuildContext context, Map<String, dynamic> policy) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating policy PDF...')),
      );
      
      // TODO: Implement PDF generation/download
      // This would typically call a cloud function or service to generate the PDF
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF download coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading PDF: $e')),
      );
    }
  }

  void _showPolicyDetails(BuildContext context, Map<String, dynamic> policy) {
    final policyNumber = policy['policyNumber'] as String?;
    final petData = policy['pet'] as Map<String, dynamic>?;
    final ownerData = policy['owner'] as Map<String, dynamic>?;
    final planData = policy['plan'] as Map<String, dynamic>?;
    final status = policy['status'] as String? ?? 'unknown';
    final effectiveDate = policy['effectiveDate'] as String?;
    final expirationDate = policy['expirationDate'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Policy #${policyNumber ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPolicyStatusColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatPolicyStatus(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Pet Information
              if (petData != null) ...[
                const Text('Pet Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Name', petData['name']),
                _buildDetailRow('Species', petData['species']),
                _buildDetailRow('Breed', petData['breed']),
                _buildDetailRow('Age', _calculateAge(petData['dateOfBirth'])),
                const SizedBox(height: 16),
              ],
              
              // Plan Information
              if (planData != null) ...[
                const Text('Plan Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Plan', planData['name']),
                _buildDetailRow('Monthly Premium', '\$${(planData['monthlyPremium'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
                _buildDetailRow('Annual Deductible', '\$${planData['annualDeductible']}'),
                _buildDetailRow('Coverage Limit', '\$${planData['maxAnnualCoverage']}'),
                const SizedBox(height: 16),
              ],
              
              // Policy Dates
              const Text('Policy Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (effectiveDate != null) _buildDetailRow('Effective Date', _formatFullDate(effectiveDate)),
              if (expirationDate != null) _buildDetailRow('Expiration Date', _formatFullDate(expirationDate)),
              const SizedBox(height: 16),
              
              // Owner Information
              if (ownerData != null) ...[
                const Text('Owner Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Name', '${ownerData['firstName']} ${ownerData['lastName']}'),
                _buildDetailRow('Email', ownerData['email']),
                _buildDetailRow('Phone', ownerData['phone']),
                _buildDetailRow('Address', '${ownerData['addressLine1']}, ${ownerData['city']}, ${ownerData['state']} ${ownerData['zipCode']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadPolicyPDF(context, policy);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  String _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return 'Unknown';
    try {
      final birthDate = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      final age = now.difference(birthDate).inDays ~/ 365;
      return '$age years old';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFullDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildPendingClaimsSection(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        if (snapshot.hasError) {
          print('Error loading claims: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        
        final allClaims = snapshot.data?.docs ?? [];
        print('DEBUG: Found ${allClaims.length} total claims for user ${user.uid}');
        
        // Filter for pending claims
        final pendingClaims = allClaims.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          return status == 'draft' || status == 'submitted' || status == 'processing';
        }).toList();
        
        print('DEBUG: Found ${pendingClaims.length} pending claims');
        
        if (pendingClaims.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ClovaraColors.kWarmCoral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      color: ClovaraColors.kWarmCoral,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pending Claims',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ClovaraColors.kWarmCoral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingClaims.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Claims List - use proper clickable cards
              ...pendingClaims.map((doc) {
                final claimData = doc.data() as Map<String, dynamic>;
                try {
                  final claim = Claim.fromMap(claimData, doc.id);
                  return _buildPendingClaimCard(context, claim);
                } catch (e) {
                  print('Error parsing claim ${doc.id}: $e');
                  // Fallback to simple card if parsing fails
                  return _buildSimpleClaimCard(context, doc.id, claimData);
                }
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleClaimCard(BuildContext context, String claimId, Map<String, dynamic> claimData) {
    final status = claimData['status'] as String? ?? 'unknown';
    final claimType = claimData['claimType'] as String? ?? 'unknown';
    final amount = (claimData['claimAmount'] as num?)?.toDouble() ?? 0.0;
    final description = claimData['description'] as String? ?? '';
    final policyId = claimData['policyId'] as String? ?? '';
    final petId = claimData['petId'] as String? ?? '';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'draft':
        statusColor = Colors.orange;
        statusIcon = Icons.edit_outlined;
        break;
      case 'submitted':
        statusColor = Colors.blue;
        statusIcon = Icons.upload_outlined;
        break;
      case 'processing':
        statusColor = ClovaraColors.clover;
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSimpleClaimTap(context, claimId, claimData, policyId, petId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$claimType (${claimId.substring(0, 8)}...)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (amount > 0)
                      Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description.length > 100 
                        ? '${description.substring(0, 100)}...'
                        : description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (status == 'draft')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tap to continue',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.5),
                      size: 14,
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

  void _handleSimpleClaimTap(BuildContext context, String claimId, Map<String, dynamic> claimData, String policyId, String petId) {
    final status = claimData['status'] as String? ?? '';
    
    if (status == 'draft') {
      // Navigate to claim intake screen to continue the draft
      if (policyId.isNotEmpty && petId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClaimIntakeScreen(
              policyId: policyId,
              petId: petId,
              draftClaimId: claimId, // Pass the draft claim ID to resume
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing policy or pet information for this claim'),
          ),
        );
      }
    } else {
      // Show claim details dialog for submitted/processing claims
      _showSimpleClaimDetailsDialog(context, claimId, claimData);
    }
  }

  void _showSimpleClaimDetailsDialog(BuildContext context, String claimId, Map<String, dynamic> claimData) {
    final status = claimData['status'] as String? ?? 'unknown';
    final claimType = claimData['claimType'] as String? ?? 'unknown';
    final amount = (claimData['claimAmount'] as num?)?.toDouble() ?? 0.0;
    final description = claimData['description'] as String? ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ClovaraColors.forest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Claim Details',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClaimDetailRow('Claim ID', claimId),
            _buildClaimDetailRow('Type', claimType),
            _buildClaimDetailRow('Status', status.toUpperCase()),
            _buildClaimDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
            if (description.isNotEmpty)
              _buildClaimDetailRow('Description', description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: ClovaraColors.clover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingClaimCard(BuildContext context, Claim claim) {
    Color statusColor;
    IconData statusIcon;
    
    switch (claim.status) {
      case ClaimStatus.draft:
        statusColor = Colors.orange;
        statusIcon = Icons.edit_outlined;
        break;
      case ClaimStatus.submitted:
        statusColor = Colors.blue;
        statusIcon = Icons.upload_outlined;
        break;
      case ClaimStatus.processing:
        statusColor = ClovaraColors.clover;
        statusIcon = Icons.hourglass_empty;
        break;
      case ClaimStatus.cancelled:
        statusColor = Colors.red.shade300;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePendingClaimTap(context, claim),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.claimType.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            claim.status.displayName,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (claim.claimAmount > 0)
                      Text(
                        '\$${claim.claimAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
                if (claim.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    claim.description.length > 100 
                        ? '${claim.description.substring(0, 100)}...'
                        : claim.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
                
                // Document status indicator for submitted claims
                if (claim.status == ClaimStatus.submitted && claim.attachments.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Awaiting supporting documents',
                          style: TextStyle(
                            color: Colors.orange.shade200,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white.withOpacity(0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_formatTimeAgo(claim.updatedAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (claim.status == ClaimStatus.draft)
                      Text(
                        'Tap to continue',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (claim.status == ClaimStatus.submitted && claim.attachments.isEmpty)
                      Text(
                        'Tap to upload documents',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (claim.status == ClaimStatus.submitted && claim.attachments.isNotEmpty)
                      Text(
                        'Tap for details',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (claim.status == ClaimStatus.cancelled)
                      Text(
                        'Cancelled',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handlePendingClaimTap(BuildContext context, Claim claim) {
    // Always show claim details dialog first
    _showClaimDetailsDialog(context, claim);
  }

  void _showClaimDetailsDialog(BuildContext context, Claim claim) {
    showDialog(
      context: context,
      builder: (context) => ClaimDetailsDialog(claim: claim),
    );
  }

  Widget _buildClaimDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentClaimsSection(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('userId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .limit(5) // Show last 5 claims
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading recent claims: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final allClaims = snapshot.data!.docs;
        print('DEBUG: Found ${allClaims.length} recent claims for user ${user.uid}');

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ClovaraColors.clover.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: ClovaraColors.clover,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Claims',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Claims List
              ...allClaims.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildRecentClaimCard(context, doc.id, data);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentClaimCard(BuildContext context, String claimId, Map<String, dynamic> claimData) {
    final claimType = claimData['claimType'] as String? ?? 'Unknown';
    final status = claimData['status'] as String? ?? 'unknown';
    final amount = (claimData['claimAmount'] as num?)?.toDouble() ?? 0.0;
    final description = claimData['description'] as String? ?? '';
    final policyId = claimData['policyId'] as String? ?? '';
    final petId = claimData['petId'] as String? ?? '';
    
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    
    switch (status) {
      case 'draft':
        statusColor = Colors.orange;
        statusIcon = Icons.edit_outlined;
        statusLabel = 'DRAFT';
        break;
      case 'submitted':
        statusColor = Colors.blue;
        statusIcon = Icons.upload_outlined;
        statusLabel = 'SUBMITTED';
        break;
      case 'processing':
        statusColor = ClovaraColors.clover;
        statusIcon = Icons.hourglass_empty;
        statusLabel = 'PROCESSING';
        break;
      case 'settled':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'APPROVED ✓';
        break;
      case 'denied':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'DENIED';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        statusLabel = 'CANCELLED';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusLabel = status.toUpperCase();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSimpleClaimTap(context, claimId, claimData, policyId, petId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1.5,
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claimType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (amount > 0)
                      Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: status == 'settled' ? Colors.green : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description.length > 80 
                        ? '${description.substring(0, 80)}...'
                        : description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, List<Map<String, dynamic>> pets) {
    final actions = [
      _ActionData(
        icon: Icons.add_circle_outline,
        title: 'Get Quote',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.clover.withOpacity(0.9),
            ClovaraColors.clover,
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ConversationalQuoteFlow(),
            ),
          );
        },
      ),
      _ActionData(
        icon: Icons.medical_services_outlined,
        title: 'File Claim',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.kWarmCoral.withOpacity(0.9),
            ClovaraColors.kWarmCoral,
          ],
        ),
        onTap: () => _handleFileClaim(context, pets),
      ),
      _ActionData(
        icon: Icons.pets,
        title: 'My Pets',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.kSuccessMint.withOpacity(0.9),
            ClovaraColors.kSuccessMint,
          ],
        ),
        onTap: () {
          _showPetsDialog(context, pets);
        },
      ),
      _ActionData(
        icon: Icons.description,
        title: 'Policies',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.sunset.withOpacity(0.9),
            ClovaraColors.sunset,
          ],
        ),
        onTap: () {
          _showPoliciesScreen(context);
        },
      ),
      _ActionData(
        icon: Icons.help_outline,
        title: 'Help',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.clover.withOpacity(0.7),
            ClovaraColors.clover.withOpacity(0.9),
          ],
        ),
        onTap: () {
          _showHelpDialog(context);
        },
      ),
      _ActionData(
        icon: Icons.support_agent,
        title: 'Support',
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9C27B0),
            Color(0xFFBA68C8),
          ],
        ),
        onTap: () {
          _showSupportDialog(context);
        },
      ),
    ];

    // Responsive grid layout - adapts to screen size
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine optimal layout based on available width
        final screenWidth = constraints.maxWidth;
        final int crossAxisCount;
        final double? cardHeight;
        final double maxContentWidth;
        
        if (screenWidth > 1200) {
          // Large desktop - 6 columns, compact cards
          crossAxisCount = 6;
          cardHeight = 140;
          maxContentWidth = 1200;
        } else if (screenWidth > 900) {
          // Desktop/tablet landscape - 6 columns
          crossAxisCount = 6;
          cardHeight = 140;
          maxContentWidth = 1000;
        } else if (screenWidth > 600) {
          // Tablet portrait - 3 columns
          crossAxisCount = 3;
          cardHeight = 140;
          maxContentWidth = 600;
        } else {
          // Mobile - 3 columns
          crossAxisCount = 3;
          cardHeight = null; // Use aspect ratio for mobile
          maxContentWidth = screenWidth;
        }
        
        // Center the grid on large screens
        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: cardHeight != null
                  ? SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: cardHeight, // Fixed height for web
                    )
                  : SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1, // Square cards for mobile
                    ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + (index * 100)),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: _ActionButtonTile(
                        action: actions[index],
                        isCompact: screenWidth > 600, // Compact mode for web
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickLinksCarousel(BuildContext context) {
    final quickLinks = [
      _QuickLinkData(
        icon: Icons.history,
        label: 'Claims History',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.sunset.withOpacity(0.3),
            ClovaraColors.sunset.withOpacity(0.5),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claims history coming soon!')),
          );
        },
      ),
      _QuickLinkData(
        icon: Icons.payment,
        label: 'Billing',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.clover.withOpacity(0.3),
            ClovaraColors.clover.withOpacity(0.5),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Billing portal coming soon!')),
          );
        },
      ),
      _QuickLinkData(
        icon: Icons.settings,
        label: 'Settings',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.kSuccessMint.withOpacity(0.3),
            ClovaraColors.kSuccessMint.withOpacity(0.5),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings coming soon!')),
          );
        },
      ),
      _QuickLinkData(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        gradient: LinearGradient(
          colors: [
            ClovaraColors.kWarmCoral.withOpacity(0.3),
            ClovaraColors.kWarmCoral.withOpacity(0.5),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications coming soon!')),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Quick Actions',
            style: ClovaraTypography.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: quickLinks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 800 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: _QuickLinkChip(link: quickLinks[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // All existing dialog and navigation methods remain unchanged
  void _handleFileClaim(BuildContext context, List<Map<String, dynamic>> pets) async {
    if (pets.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Pets Found'),
          content: const Text('You need to add a pet before filing a claim. Would you like to get a quote and add a pet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationalQuoteFlow(),
                  ),
                );
              },
              child: const Text('Get Quote'),
            ),
          ],
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final policiesSnapshot = await FirebaseFirestore.instance
        .collection('policies')
        .where('ownerId', isEqualTo: user?.uid)  // Changed from userId to ownerId
        .get();

    if (policiesSnapshot.docs.isEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Active Policy'),
            content: const Text('You need an active policy to file a claim. Would you like to get a quote?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConversationalQuoteFlow(),
                    ),
                  );
                },
                child: const Text('Get Quote'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final firstPolicy = policiesSnapshot.docs.first;
    final policyId = firstPolicy.id;
    final petId = pets.first['id'] as String? ?? 'unknown';

    if (context.mounted) {
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• How do I file a claim?'),
              Text('• What is covered by my policy?'),
              Text('• How long does claim processing take?'),
              Text('• How do I update my payment method?'),
              SizedBox(height: 16),
              Text('For more detailed help, please contact our support team.'),
            ],
          ),
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

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              subtitle: Text('support@petuwrite.com'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Phone'),
              subtitle: Text('1-800-PET-WRITE'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text('Hours'),
              subtitle: Text('Mon-Fri: 9AM-6PM EST'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
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

  void _showProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          final userProfile = snapshot.data ?? {};
          final firstName = userProfile['firstName'] as String?;
          final lastName = userProfile['lastName'] as String?;
          final zipCode = userProfile['zipCode'] as String?;
          
          return AlertDialog(
            title: const Text('My Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (firstName != null || user?.displayName != null)
                    ListTile(
                      leading: const Icon(Icons.person, color: ClovaraColors.forest),
                      title: const Text('Name'),
                      subtitle: Text(
                        firstName != null && lastName != null
                            ? '$firstName $lastName'
                            : firstName ?? user?.displayName ?? 'Not set',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ListTile(
                    leading: const Icon(Icons.email, color: ClovaraColors.forest),
                    title: const Text('Email'),
                    subtitle: Text(user?.email ?? 'Not available'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (zipCode != null)
                    ListTile(
                      leading: const Icon(Icons.location_on, color: ClovaraColors.forest),
                      title: const Text('Zip Code'),
                      subtitle: Text(zipCode),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ListTile(
                    leading: const Icon(Icons.badge, color: ClovaraColors.clover),
                    title: const Text('Account Type'),
                    subtitle: Text(widget.isPremium ? 'Premium' : 'Regular'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.grey),
                    title: Text(
                      'Member since ${_formatDate(user?.metadata.creationTime)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // Close the dialog first
                  Navigator.pop(context);
                  
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();
                  
                  // Navigate to auth gate and clear all routes
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/auth-gate',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<Map<String, dynamic>> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data() ?? {};
    } catch (e) {
      print('Error fetching user profile: $e');
      return {};
    }
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  void _showPetsDialog(BuildContext context, List<Map<String, dynamic>> pets) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Pets'),
        content: SizedBox(
          width: double.maxFinite,
          child: pets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No pets added yet.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(pet['name'] ?? 'Unknown'),
                      subtitle: Text('${pet['species'] ?? 'Pet'} • ${pet['breed'] ?? 'Mixed'}'),
                    );
                  },
                ),
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

  void _showPoliciesScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _PoliciesListScreen(),
      ),
    );
  }
}

// ============================================================================
// MODERN UI COMPONENTS
// ============================================================================

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.amber.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: ClovaraTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ProfileButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final String count;
  final String label;
  final LinearGradient gradient;
  final Duration delay;

  const _AnimatedStatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.gradient,
    required this.delay,
  });

  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    widget.count,
                    style: ClovaraTypography.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String title;
  final LinearGradient gradient;
  final VoidCallback onTap;

  _ActionData({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });
}

class _ActionButtonTile extends StatefulWidget {
  final _ActionData action;
  final bool isCompact;

  const _ActionButtonTile({
    required this.action,
    this.isCompact = false,
  });

  @override
  State<_ActionButtonTile> createState() => _ActionButtonTileState();
}

class _ActionButtonTileState extends State<_ActionButtonTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Responsive sizing based on isCompact mode (web vs mobile)
    final iconSize = widget.isCompact ? 36.0 : 32.0;
    final titleSize = widget.isCompact ? 14.0 : 13.0;
    final spacing = widget.isCompact ? 10.0 : 8.0;
    final borderRadius = widget.isCompact ? 16.0 : 20.0;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.action.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.action.gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.action.gradient.colors.first.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCompact ? 12 : 8,
                  vertical: widget.isCompact ? 16 : 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.action.icon,
                      color: Colors.white,
                      size: iconSize,
                    ),
                    SizedBox(height: spacing),
                    Text(
                      widget.action.title,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleSize,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickLinkData {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  _QuickLinkData({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}

class _QuickLinkChip extends StatefulWidget {
  final _QuickLinkData link;

  const _QuickLinkChip({required this.link});

  @override
  State<_QuickLinkChip> createState() => _QuickLinkChipState();
}

class _QuickLinkChipState extends State<_QuickLinkChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.link.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.link.gradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.link.gradient.colors.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.link.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.link.label,
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTERS & CLIPPERS
// ============================================================================

class _CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// POLICIES LIST SCREEN (Unchanged)
// ============================================================================

class _PoliciesListScreen extends StatelessWidget {
  const _PoliciesListScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Policies'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('policies')
            .where('ownerId', isEqualTo: user?.uid)  // Changed from userId to ownerId
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No policies yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Get a quote to start your first policy'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuoteFlowScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Get Quote'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final policy = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final status = policy['status'] ?? 'unknown';
              final policyNumber = policy['policyNumber'] ?? 'N/A';
              final planData = policy['plan'] as Map<String, dynamic>?;
              final premium = planData?['monthlyPremium'] ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status),
                    child: const Icon(Icons.description, color: Colors.white),
                  ),
                  title: Text('Policy #$policyNumber'),
                  subtitle: Text(
                    'Status: ${_formatStatus(status)}\n\$${premium.toStringAsFixed(2)}/month',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Show a simple policy info dialog  
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Policy #$policyNumber'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Status: ${_formatStatus(status)}'),
                            Text('Premium: \$${premium.toStringAsFixed(2)}/month'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  void _showPolicyDetails(BuildContext context, Map<String, dynamic> policy) {
    final policyNumber = policy['policyNumber'] as String?;
    final petData = policy['pet'] as Map<String, dynamic>?;
    final ownerData = policy['owner'] as Map<String, dynamic>?;
    final planData = policy['plan'] as Map<String, dynamic>?;
    final status = policy['status'] as String? ?? 'unknown';
    final effectiveDate = policy['effectiveDate'] as String?;
    final expirationDate = policy['expirationDate'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Policy #${policyNumber ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatStatus(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Pet Information
              if (petData != null) ...[
                const Text('Pet Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Name', petData['name']),
                _buildDetailRow('Species', petData['species']),
                _buildDetailRow('Breed', petData['breed']),
                _buildDetailRow('Age', _calculateAge(petData['dateOfBirth'])),
                const SizedBox(height: 16),
              ],
              
              // Plan Information
              if (planData != null) ...[
                const Text('Plan Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Plan', planData['name']),
                _buildDetailRow('Monthly Premium', '\$${(planData['monthlyPremium'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
                _buildDetailRow('Annual Deductible', '\$${planData['annualDeductible']}'),
                _buildDetailRow('Coverage Limit', '\$${planData['maxAnnualCoverage']}'),
                const SizedBox(height: 16),
              ],
              
              // Policy Dates
              const Text('Policy Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (effectiveDate != null) _buildDetailRow('Effective Date', _formatFullDate(effectiveDate)),
              if (expirationDate != null) _buildDetailRow('Expiration Date', _formatFullDate(expirationDate)),
              const SizedBox(height: 16),
              
              // Owner Information
              if (ownerData != null) ...[
                const Text('Owner Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDetailRow('Name', '${ownerData['firstName']} ${ownerData['lastName']}'),
                _buildDetailRow('Email', ownerData['email']),
                _buildDetailRow('Phone', ownerData['phone']),
                _buildDetailRow('Address', '${ownerData['addressLine1']}, ${ownerData['city']}, ${ownerData['state']} ${ownerData['zipCode']}'),
              ],
            ],
          ),
        ),
        actions: [
          if (status == 'active') ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showCancelPolicyDialog(context, policy);
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text('Cancel Policy', style: TextStyle(color: Colors.red)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  String _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return 'Unknown';
    try {
      final birthDate = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      final age = now.difference(birthDate).inDays ~/ 365;
      return '$age years old';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFullDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showCancelPolicyDialog(BuildContext context, Map<String, dynamic> policy) {
    final policyId = policy['id'] as String?;
    final policyNumber = policy['policyNumber'] as String?;
    
    if (policyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Policy ID not found')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ClovaraColors.forest,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade300),
            const SizedBox(width: 12),
            const Text(
              'Cancel Policy?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel Policy #$policyNumber?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red.shade300, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Coverage ends immediately\n'
                    '• No refunds for current billing period\n'
                    '• Pre-existing conditions may not be covered if you reapply\n'
                    '• Pending claims will still be processed\n'
                    '• This action cannot be undone',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'If you\'re having issues, please contact our support team first. We\'re here to help!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Policy',
              style: TextStyle(
                color: ClovaraColors.kSuccessMint,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPolicyCancellation(context, policyId, policyNumber ?? 'Unknown');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel Policy'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPolicyCancellation(BuildContext context, String policyId, String policyNumber) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cancelling policy...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Update policy status in Firestore
      await FirebaseFirestore.instance
          .collection('policies')
          .doc(policyId)
          .update({
        'status': 'cancelled',
        'cancellationDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellationReason': 'Customer requested cancellation',
      });

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ClovaraColors.forest,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: ClovaraColors.kSuccessMint),
                const SizedBox(width: 12),
                const Text(
                  'Policy Cancelled',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Policy #$policyNumber has been cancelled successfully.',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: ClovaraColors.clover, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'What happens next?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Coverage ended as of today\n'
                        '• Any pending claims will be processed\n'
                        '• You\'ll receive a confirmation email\n'
                        '• No further charges will be made',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'re sorry to see you go. If you change your mind, you can always get a new quote!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: ClovaraColors.kSuccessMint),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling policy: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _processPolicyCancellation(context, policyId, policyNumber),
            ),
          ),
        );
      }
    }
  }
}

/// Enhanced claim details dialog with document upload functionality
class ClaimDetailsDialog extends StatefulWidget {
  final Claim claim;

  const ClaimDetailsDialog({
    super.key,
    required this.claim,
  });

  @override
  State<ClaimDetailsDialog> createState() => _ClaimDetailsDialogState();
}

class _ClaimDetailsDialogState extends State<ClaimDetailsDialog> {
  final ClaimsService _claimsService = ClaimsService();
  bool _isUploading = false;
  List<String> _attachmentUrls = [];

  @override
  void initState() {
    super.initState();
    _attachmentUrls = List.from(widget.claim.attachments);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ClovaraColors.forest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Claim Details',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClaimDetailRow('Claim ID', widget.claim.claimId),
            _buildClaimDetailRow('Type', widget.claim.claimType.displayName),
            _buildClaimDetailRow('Status', widget.claim.status.displayName),
            _buildClaimDetailRow('Amount', '\$${widget.claim.claimAmount.toStringAsFixed(2)}'),
            _buildClaimDetailRow('Incident Date', _formatFullDate(widget.claim.incidentDate.toIso8601String())),
            if (widget.claim.description.isNotEmpty)
              _buildClaimDetailRow('Description', widget.claim.description),
            
            const SizedBox(height: 16),
            
            // Documents section
            Text(
              'Supporting Documents',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_attachmentUrls.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_outlined, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No documents uploaded yet. Upload vet records and receipts to start the review process.',
                        style: TextStyle(color: Colors.orange.shade200, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_attachmentUrls.map((url) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document ${_attachmentUrls.indexOf(url) + 1}',
                        style: TextStyle(color: Colors.green.shade200, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ))),
            
            const SizedBox(height: 12),
            
            // Upload button for submitted claims
            if (widget.claim.status == ClaimStatus.submitted || widget.claim.status == ClaimStatus.draft)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _handleDocumentUpload,
                  icon: _isUploading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.upload_file),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload Documents'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClovaraColors.clover,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        // Delete button for draft claims only
        if (widget.claim.status == ClaimStatus.draft)
          TextButton(
            onPressed: _handleDeleteClaim,
            child: Text(
              'Delete Draft',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        // Continue button for draft claims
        if (widget.claim.status == ClaimStatus.draft)
          ElevatedButton(
            onPressed: _handleContinueDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: ClovaraColors.clover,
              foregroundColor: Colors.white,
            ),
            child: Text('Continue Draft'),
          ),
        // Cancel button for cancellable claims (excluding drafts)
        if (_canCancelClaim() && widget.claim.status != ClaimStatus.draft)
          TextButton(
            onPressed: _handleCancelClaim,
            child: Text(
              'Cancel Claim',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(color: ClovaraColors.clover),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _handleDocumentUpload() async {
    setState(() => _isUploading = true);
    
    try {
      // Use file picker for web
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          // On web, use bytes; on mobile, use path
          if (file.bytes != null) {
            // Web: Upload using bytes
            final url = await _claimsService.uploadClaimDocumentFromBytes(
              file.bytes!,
              file.name,
              widget.claim.claimId,
            );
            
            setState(() {
              _attachmentUrls.add(url);
            });
          } else if (file.path != null) {
            // Mobile: Upload using file path
            final url = await _claimsService.uploadClaimDocument(
              file.path!,
              widget.claim.claimId,
            );
            
            setState(() {
              _attachmentUrls.add(url);
            });
          }
        }
        
        // Update claim with new attachments
        await _updateClaimWithDocuments();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documents uploaded successfully! AI review will begin automatically.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload documents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _updateClaimWithDocuments() async {
    try {
      // Update claim in Firestore with new attachments
      await FirebaseFirestore.instance
          .collection('claims')
          .doc(widget.claim.claimId)
          .update({
        'attachments': _attachmentUrls,
        'updatedAt': FieldValue.serverTimestamp(),
        // Move to processing if it was just submitted
        if (widget.claim.status == ClaimStatus.submitted)
          'status': ClaimStatus.processing.value,
      });

      // Trigger AI review for submitted claims with new documents
      if (widget.claim.status == ClaimStatus.submitted && _attachmentUrls.isNotEmpty) {
        await _triggerAIReview();
      }
    } catch (e) {
      print('Error updating claim: $e');
    }
  }

  Future<void> _triggerAIReview() async {
    try {
      // Create updated claim object for AI review
      final updatedClaim = Claim(
        claimId: widget.claim.claimId,
        policyId: widget.claim.policyId,
        ownerId: widget.claim.ownerId,
        petId: widget.claim.petId,
        incidentDate: widget.claim.incidentDate,
        claimType: widget.claim.claimType,
        claimAmount: widget.claim.claimAmount,
        description: widget.claim.description,
        attachments: _attachmentUrls,
        status: ClaimStatus.processing,
        createdAt: widget.claim.createdAt,
        updatedAt: DateTime.now(),
      );

      // Trigger AI decision engine
      final engine = ClaimDecisionEngine();
      final decision = await engine.processClaimDecision(claim: updatedClaim);
      
      print('AI review triggered for claim ${widget.claim.claimId}');
      print('Decision: ${decision.aiDecision.value}, Confidence: ${decision.aiConfidenceScore}');
    } catch (e) {
      print('Error triggering AI review: $e');
    }
  }

  /// Check if claim can be cancelled
  bool _canCancelClaim() {
    // Allow cancellation for draft, submitted, and processing claims
    // Don't allow cancellation for settled, denied, or cancelled claims
    return widget.claim.status == ClaimStatus.draft ||
           widget.claim.status == ClaimStatus.submitted ||
           widget.claim.status == ClaimStatus.processing;
  }

  /// Handle claim cancellation with confirmation
  Future<void> _handleCancelClaim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ClovaraColors.forest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Cancel Claim',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to cancel this claim? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Claim',
              style: TextStyle(color: ClovaraColors.clover),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancel Claim',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelClaim();
    }
  }

  /// Cancel the claim by updating its status
  Future<void> _cancelClaim() async {
    try {
      // Update claim status to cancelled
      await FirebaseFirestore.instance
          .collection('claims')
          .doc(widget.claim.claimId)
          .update({
        'status': ClaimStatus.cancelled.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Show success message and close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claim has been cancelled successfully.'),
          backgroundColor: Colors.orange,
        ),
      );

      // Close the dialog
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle draft claim deletion with confirmation
  Future<void> _handleDeleteClaim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ClovaraColors.forest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Draft',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this draft claim? This will permanently remove all information and cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Draft',
              style: TextStyle(color: ClovaraColors.clover),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete Draft',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteClaim();
    }
  }

  /// Permanently delete the draft claim from Firestore
  Future<void> _deleteClaim() async {
    try {
      // Delete the claim document from Firestore
      await FirebaseFirestore.instance
          .collection('claims')
          .doc(widget.claim.claimId)
          .delete();

      // Show success message and close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft claim has been deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Close the dialog
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete draft claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle continuing a draft claim
  void _handleContinueDraft() {
    // Close the details dialog first
    Navigator.pop(context);
    
    // Navigate to claim intake screen to continue the draft
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimIntakeScreen(
          policyId: widget.claim.policyId,
          petId: widget.claim.petId,
          draftClaimId: widget.claim.claimId,
        ),
      ),
    );
  }
}

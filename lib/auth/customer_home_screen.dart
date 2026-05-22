import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/tokens.dart';
import '../screens/conversational_quote_flow.dart';
import '../screens/claims/claim_intake_screen.dart';
import '../screens/claims/claim_details_screen.dart';
import '../screens/claims/claims_list_screen.dart';
import '../screens/policy_details_screen.dart';
import '../screens/underwriting_followup_documents_screen.dart';
import '../services/user_session_service.dart';
import '../services/underwriting_case_service.dart';
import '../utils/marketing_site_redirect.dart';

/// Modern Clovara Customer Dashboard
/// Clean white background with gradient accent cards
class CustomerHomeScreen extends StatefulWidget {
  final bool isPremium;

  const CustomerHomeScreen({super.key, this.isPremium = false});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  static String _normalizePolicyStatus(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return '';
    final lower = text.toLowerCase();
    // Support legacy enum-style serialization like "PolicyStatus.active".
    if (lower.startsWith('policystatus.')) {
      return lower.substring('policystatus.'.length);
    }
    return lower;
  }

  static DateTime? _parsePolicyDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (raw is int) {
      // Best-effort: some legacy docs may store millis.
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return null;
  }

  static String? _policyPetId(Map<String, dynamic> data) {
    final pet = data['pet'];
    if (pet is Map) {
      final id = pet['id'] ?? pet['petId'];
      final text = id?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    final fallback = data['petId']?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  static DateTime _policySortDate(Map<String, dynamic> data) {
    final createdAt = _parsePolicyDate(data['createdAt']);
    final effectiveDate = _parsePolicyDate(data['effectiveDate']);
    return createdAt ?? effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static bool _isActivePolicy(Map<String, dynamic> data) {
    final status = _normalizePolicyStatus(data['status']);
    if (status != 'active') return false;

    final now = DateTime.now();
    final effectiveDate = _parsePolicyDate(data['effectiveDate']);
    final expirationDate = _parsePolicyDate(data['expirationDate']);

    if (effectiveDate != null && now.isBefore(effectiveDate)) {
      return false;
    }
    if (expirationDate != null && !now.isBefore(expirationDate)) {
      return false;
    }
    return true;
  }

  static List<QueryDocumentSnapshot> _dedupePoliciesByPet(
    List<QueryDocumentSnapshot> policies,
  ) {
    final byPetId = <String, QueryDocumentSnapshot>{};

    for (final doc in policies) {
      final data = (doc.data() as Map).cast<String, dynamic>();
      final petId = _policyPetId(data) ?? doc.id;
      final existing = byPetId[petId];
      if (existing == null) {
        byPetId[petId] = doc;
        continue;
      }

      final existingData = (existing.data() as Map).cast<String, dynamic>();
      if (_policySortDate(data).isAfter(_policySortDate(existingData))) {
        byPetId[petId] = doc;
      }
    }

    final deduped = byPetId.values.toList(growable: false);
    deduped.sort((a, b) {
      final ad = (a.data() as Map).cast<String, dynamic>();
      final bd = (b.data() as Map).cast<String, dynamic>();
      return _policySortDate(bd).compareTo(_policySortDate(ad));
    });
    return deduped;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 720;
    final horizontalPadding = isMobile ? 20.0 : 40.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF4),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _PortalBackdrop()),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isMobile ? 18 : 28,
                      horizontalPadding,
                      16,
                    ),
                    child: MaxWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(context, user, isMobile),
                          SizedBox(height: isMobile ? 24 : 36),
                          _buildHeroTopCards(user, isMobile),
                          const SizedBox(height: 18),
                          _buildQuickActions(context, isMobile),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 6,
                    ),
                    child: MaxWidth(
                      child: _PortalSection(
                        title: 'Next best actions',
                        subtitle:
                            'The portal keeps underwriting, claims, and coverage tasks in one place.',
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 860 ? 3 : 1;
                            final itemWidth =
                                (constraints.maxWidth - (12 * (columns - 1))) /
                                columns;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: itemWidth,
                                  child: const _StatusBrief(
                                    icon: Icons.verified_outlined,
                                    title: 'Coverage',
                                    body:
                                        'Review active policies, plan details, exclusions, and documents.',
                                    color: Color(0xFF2D8F73),
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: const _StatusBrief(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Claims',
                                    body:
                                        'Start a claim, continue a draft, or track reimbursement status.',
                                    color: Color(0xFFE58B3A),
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: const _StatusBrief(
                                    icon: Icons.fact_check_outlined,
                                    title: 'Underwriting',
                                    body:
                                        'Upload any follow-up documents needed to complete a quote.',
                                    color: Color(0xFF5B8DD6),
                                  ),
                                ),
                              ],
                            );
                          },
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
                      child: _buildPendingQuotesSection(
                        context,
                        user,
                        isMobile,
                      ),
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

                // Bottom Padding
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroTopCards(User? user, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;
        final welcome = _buildWelcomeMessage(user, isMobile);
        final stats = _buildQuickStats(user, isMobile);

        if (!isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [welcome, const SizedBox(height: 14), stats],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: welcome),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: stats),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, User? user, bool isMobile) {
    return Row(
      children: [
        ClovaraLogo(size: ClovaraLogoSize.medium, showText: true),
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
    final email = user?.email?.trim();

    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7E8), Color(0xFFEAF8F1), Color(0xFFEAF3FF)],
        ),
        borderRadius: AppRadii.br20,
        border: Border.all(color: const Color(0xFFD6E8DC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF126B4D).withOpacity(0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isMobile)
            Positioned(
              right: 4,
              bottom: -8,
              child: _FloatingPortalIllustration(controller: _floatController),
            ),
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 0 : 210),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Policyholder portal',
                  style: GoogleFonts.dmSans(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Welcome back.',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.text,
                    fontSize: isMobile ? 38 : 52,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Everything for your pets lives here: coverage, claims, documents, and next steps.',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textMuted,
                    fontSize: 16,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _PortalBadge(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Protected pets',
                      backgroundColor: Color(0xFFFFFFFF),
                    ),
                    if (email != null && email.isNotEmpty)
                      _PortalBadge(
                        icon: Icons.lock_outline,
                        label: email,
                        backgroundColor: const Color(0xFFFFFFFF),
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

  Widget _buildQuickStats(User? user, bool isMobile) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
        final active = docs
            .where(
              (d) => _isActivePolicy((d.data() as Map).cast<String, dynamic>()),
            )
            .toList(growable: false);
        final deduped = _dedupePoliciesByPet(active);
        final uniquePets = <String>{
          for (final d in deduped)
            _policyPetId((d.data() as Map).cast<String, dynamic>()) ?? d.id,
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            // Prefer a clean 2-up row on most mobile widths; only stack when
            // extremely narrow.
            final stacked = constraints.maxWidth < 360;
            final children = [
              _buildStatCard(
                icon: Icons.pets,
                count: uniquePets.length.toString(),
                label: 'Pets',
                accent: const Color(0xFF2D8F73),
                tint: const Color(0xFFEAF8F1),
                isMobile: isMobile,
              ),
              _buildStatCard(
                icon: Icons.description_outlined,
                count: deduped.length.toString(),
                label: 'Policies',
                accent: const Color(0xFFDA8A25),
                tint: const Color(0xFFFFF3DF),
                isMobile: isMobile,
              ),
            ];

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
    required Color accent,
    required Color tint,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, tint],
        ),
        borderRadius: AppRadii.br20,
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.18)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: GoogleFonts.playfairDisplay(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 28 : 34,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingQuotesSection(
    BuildContext context,
    User? user,
    bool isMobile,
  ) {
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
                .map(
                  (quote) => _buildPendingQuoteCard(context, quote, isMobile),
                )
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
    BuildContext context,
    Map<String, dynamic> quote,
    bool isMobile,
  ) {
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

  Widget _buildPoliciesSection(
    BuildContext context,
    User? user,
    bool isMobile,
  ) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PortalSkeleton(title: 'My policies');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _PortalSection(
            title: 'My policies',
            subtitle: 'Your active coverage will appear here after checkout.',
            child: _PortalEmptyState(
              icon: Icons.policy_outlined,
              title: 'No active policies yet',
              body:
                  'Start a quote when you are ready. If a policy is pending payment or underwriting, it will appear in your action center.',
              actionLabel: 'Get a quote',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationalQuoteFlow(),
                  ),
                );
              },
            ),
          );
        }

        final active = snapshot.data!.docs
            .where(
              (d) => _isActivePolicy((d.data() as Map).cast<String, dynamic>()),
            )
            .toList(growable: false);
        if (active.isEmpty) {
          return _PortalSection(
            title: 'My policies',
            subtitle: 'Your active coverage will appear here after checkout.',
            child: _PortalEmptyState(
              icon: Icons.policy_outlined,
              title: 'No active policies yet',
              body:
                  'You may still have quotes, underwriting follow-ups, or drafts in progress above.',
              actionLabel: 'Start a quote',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationalQuoteFlow(),
                  ),
                );
              },
            ),
          );
        }
        final policies = _dedupePoliciesByPet(active);

        return _PortalSection(
          title: 'My policies',
          subtitle: 'Your active coverage at a glance.',
          child: Column(
            children: policies
                .take(3)
                .map((policy) {
                  final data = policy.data() as Map<String, dynamic>;
                  return _buildPolicyCard(context, policy.id, data, isMobile);
                })
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildPolicyCard(
    BuildContext context,
    String policyId,
    Map<String, dynamic> policy,
    bool isMobile,
  ) {
    final petData = policy['pet'] as Map<String, dynamic>?;
    final petName = petData?['name'] as String? ?? 'Pet';
    final petBreed = petData?['breed']?.toString().trim();
    final planData = policy['plan'] as Map<String, dynamic>?;
    final planName = planData?['name'] as String? ?? 'Policy';
    final monthlyPremium = planData?['monthlyPremium'] as num?;
    final deductible =
        planData?['annualDeductible'] ??
        planData?['deductible'] ??
        policy['annualDeductible'] ??
        policy['deductible'];
    final reimbursement =
        planData?['reimbursementPercent'] ??
        planData?['reimbursement'] ??
        policy['reimbursementPercent'] ??
        policy['reimbursement'] ??
        _reimbursementFromCopay(planData?['coPayPercentage']);
    final effectiveDate = _parsePolicyDate(policy['effectiveDate']);
    final expirationDate = _parsePolicyDate(policy['expirationDate']);
    final billingStatus = (policy['billingStatus'] ?? policy['paymentStatus'])
        ?.toString()
        .trim();
    final exclusionsCount = _policyExclusionsCount(policy);
    final accent = _petAccentColor(petName);
    final petKind = _petKind(petData, petBreed);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.br20,
        child: InkWell(
          borderRadius: AppRadii.br20,
          onTap: () => _openPolicyDetails(context, policyId, policy),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, accent.withOpacity(0.1)],
              ),
              borderRadius: AppRadii.br20,
              border: Border.all(color: accent.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -10,
                  bottom: -16,
                  child: Icon(
                    Icons.pets,
                    color: accent.withOpacity(0.08),
                    size: 120,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PetAvatar(
                          name: petName,
                          kind: petKind,
                          color: accent,
                          size: 62,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    petName,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                  _PortalBadge(
                                    icon: Icons.check_circle_outline,
                                    label: 'Active',
                                    backgroundColor: accent.withOpacity(0.1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                [
                                  planName,
                                  if (petBreed != null && petBreed.isNotEmpty)
                                    petBreed,
                                ].join(' • '),
                                style: GoogleFonts.dmSans(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (monthlyPremium != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '\$${monthlyPremium.toStringAsFixed(0)}/mo',
                            style: GoogleFonts.playfairDisplay(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PolicyFact(
                          label: 'Deductible',
                          value: deductible == null
                              ? 'On file'
                              : _formatMoneyValue(deductible),
                        ),
                        _PolicyFact(
                          label: 'Reimbursement',
                          value: reimbursement == null
                              ? 'On file'
                              : _formatPercentValue(reimbursement),
                        ),
                        _PolicyFact(
                          label: 'Effective',
                          value: effectiveDate == null
                              ? 'Active'
                              : DateFormat.MMMd().format(effectiveDate),
                        ),
                        _PolicyFact(
                          label: 'Renews',
                          value: expirationDate == null
                              ? 'On file'
                              : DateFormat.MMMd().format(expirationDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PolicyControlsGrid(
                      items: [
                        _PolicyControlData(
                          icon: Icons.description_outlined,
                          title: 'Documents',
                          value: 'Policy packet ready',
                          color: accent,
                        ),
                        _PolicyControlData(
                          icon: Icons.payments_outlined,
                          title: 'Billing',
                          value: billingStatus == null || billingStatus.isEmpty
                              ? 'On file'
                              : _humanizeStatus(billingStatus),
                          color: const Color(0xFFE58B3A),
                        ),
                        _PolicyControlData(
                          icon: Icons.block_outlined,
                          title: 'Exclusions',
                          value: exclusionsCount == null
                              ? 'View terms'
                              : exclusionsCount == 0
                              ? 'None listed'
                              : '$exclusionsCount listed',
                          color: const Color(0xFF5B8DD6),
                        ),
                        _PolicyControlData(
                          icon: Icons.schedule_outlined,
                          title: 'Waiting periods',
                          value: 'Accidents day 1',
                          color: const Color(0xFF8E6AD8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            _openPolicyDetails(context, policyId, policy),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Manage policy'),
                        style: TextButton.styleFrom(foregroundColor: accent),
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

  Widget _buildRecentClaimsSection(
    BuildContext context,
    User? user,
    bool isMobile,
  ) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PortalSkeleton(title: 'Recent claims');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _PortalSection(
            title: 'Recent claims',
            subtitle: 'Track reimbursement status when care happens.',
            child: _PortalEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No claims yet',
              body:
                  'When you file a claim, this area will show the current status, amount, and next step.',
              actionLabel: 'File a claim',
              onAction: () => _handleFileClaim(context),
            ),
          );
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
    BuildContext context,
    QueryDocumentSnapshot claimDoc,
    bool isMobile,
  ) {
    final claim = claimDoc.data() as Map<String, dynamic>;
    final claimType = claim['claimType'] as String? ?? 'Claim';
    final status = claim['status'] as String? ?? 'pending';
    final amount = (claim['claimAmount'] as num?)?.toDouble() ?? 0.0;
    final updatedAt = _parsePolicyDate(claim['updatedAt']);

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

    final statusLabel = _humanizeStatus(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PortalListItem(
        leading:
            (status.toLowerCase() == 'settled' ||
                status.toLowerCase() == 'approved')
            ? Icons.check_circle
            : (status.toLowerCase() == 'settling')
            ? Icons.payments
            : Icons.pending,
        leadingColor: statusColor,
        title: claimType,
        subtitle: updatedAt == null
            ? statusLabel
            : '$statusLabel • Updated ${DateFormat.MMMd().format(updatedAt)}',
        trailing: amount > 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PortalBadge(
                    label: statusLabel,
                    backgroundColor: statusColor.withOpacity(0.12),
                  ),
                ],
              )
            : _PortalBadge(
                label: statusLabel,
                backgroundColor: statusColor.withOpacity(0.12),
              ),
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
        'color': const Color(0xFF2D8F73),
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
        'color': const Color(0xFFE58B3A),
        'onTap': () => _handleFileClaim(context),
      },
      {
        'icon': Icons.help_outline,
        'title': 'Help & Support',
        'subtitle': 'Get assistance',
        'color': const Color(0xFF5B8DD6),
        'onTap': () => _showHelpDialog(context),
      },
    ];

    return _PortalSection(
      title: 'Quick actions',
      subtitle: 'Start a quote, file a claim, or get support.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 3
              : (constraints.maxWidth >= 640 ? 2 : 1);
          final itemWidth =
              (constraints.maxWidth - (12 * (columns - 1))) / columns;

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
                      color: action['color'] as Color,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error resuming quote: $e')));
      }
    }
  }

  void _openPolicyDetails(
    BuildContext context,
    String policyId,
    Map<String, dynamic> policy,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PolicyDetailsScreen(policyId: policyId, initialData: policy),
      ),
    );
  }

  void _handleFileClaim(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load policies and recent claims (client-side filter drafts to avoid
    // requiring extra composite indexes).
    final policiesSnapshot = await FirebaseFirestore.instance
        .collection('policies')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    final allPolicies = policiesSnapshot.docs;
    final activePolicies = allPolicies
        .where(
          (p) => _isActivePolicy((p.data() as Map).cast<String, dynamic>()),
        )
        .toList(growable: false);
    final claimablePolicies = _dedupePoliciesByPet(activePolicies);

    if (claimablePolicies.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need an active policy to file a claim'),
        ),
      );
      return;
    }

    final recentClaimsSnapshot = await FirebaseFirestore.instance
        .collection('claims')
        .where('ownerId', isEqualTo: user.uid)
        .limit(30)
        .get();

    final policyPetNameByPetId = <String, String>{};
    for (final p in claimablePolicies) {
      final data = (p.data() as Map).cast<String, dynamic>();
      final petId = _policyPetId(data);
      if (petId == null) continue;

      final pet = data['pet'];
      final name = (pet is Map ? pet['name'] : null)?.toString().trim() ?? '';
      policyPetNameByPetId[petId] = name.isEmpty ? 'Pet' : name;
    }

    final drafts =
        recentClaimsSnapshot.docs
            .where(
              (d) =>
                  (d.data()['status'] as String? ?? '').toLowerCase() ==
                  'draft',
            )
            .toList(growable: false)
          ..sort((a, b) {
            final ta = a.data()['updatedAt'];
            final tb = b.data()['updatedAt'];
            final da = ta is Timestamp
                ? ta.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final db = tb is Timestamp
                ? tb.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'File a claim',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drafts.isEmpty
                        ? 'Start a new claim for a policy below.'
                        : 'Start a new claim, or continue a draft.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),

                  if (drafts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Continue a draft',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final d in drafts.take(8)) ...[
                      _PortalListItem(
                        leading: Icons.chat_bubble_outline,
                        title: _draftTitle(d.data()),
                        subtitle: _draftSubtitle(
                          d.data(),
                          policyPetNameByPetId,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSubtle,
                        ),
                        onTap: () {
                          final data = d.data();
                          final policyId = (data['policyId'] as String?) ?? '';
                          final petId = (data['petId'] as String?) ?? '';
                          if (policyId.isEmpty || petId.isEmpty) return;
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClaimIntakeScreen(
                                policyId: policyId,
                                petId: petId,
                                draftClaimId: d.id,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],

                  const SizedBox(height: 8),
                  Text(
                    'Start a new claim',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final p in claimablePolicies) ...[
                    _PortalListItem(
                      leading: Icons.description_outlined,
                      title: _policyTitle(
                        (p.data() as Map).cast<String, dynamic>(),
                      ),
                      subtitle: _policySubtitle(
                        (p.data() as Map).cast<String, dynamic>(),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.green,
                      ),
                      onTap: () {
                        final data = (p.data() as Map).cast<String, dynamic>();
                        final petData = data['pet'] as Map<String, dynamic>?;
                        final petId = petData?['id']?.toString();
                        if (petId == null || petId.isEmpty) return;

                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClaimIntakeScreen(
                              policyId: p.id,
                              petId: petId,
                              ignoreExistingDrafts: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _draftTitle(Map<String, dynamic> data) {
    final type = (data['claimType'] as String?)?.trim();
    if (type == null || type.isEmpty) return 'Draft claim';
    return '${type[0].toUpperCase()}${type.substring(1)} claim';
  }

  static String _draftSubtitle(
    Map<String, dynamic> data,
    Map<String, String> petNameByPetId,
  ) {
    final petId = (data['petId'] as String?)?.trim();
    final petName = (petId != null && petId.isNotEmpty)
        ? (petNameByPetId[petId] ?? 'Pet')
        : 'Pet';
    final incident = data['incidentDate'];
    final date = incident is Timestamp
        ? incident.toDate()
        : (incident is DateTime ? incident : null);
    final dateText = date == null
        ? 'In progress'
        : 'Incident ${DateFormat.yMMMd().format(date)}';
    return '$petName • $dateText';
  }

  static String _policyTitle(Map<String, dynamic> data) {
    final petData = data['pet'] as Map<String, dynamic>?;
    final petName = petData?['name']?.toString().trim();
    return (petName == null || petName.isEmpty) ? 'Policy' : petName;
  }

  static String _policySubtitle(Map<String, dynamic> data) {
    final planData = data['plan'] as Map<String, dynamic>?;
    final planName = planData?['name']?.toString().trim();
    return (planName == null || planName.isEmpty)
        ? 'Start a new claim'
        : planName;
  }

  static Color _petAccentColor(String petName) {
    const colors = [
      Color(0xFF2D8F73),
      Color(0xFFE58B3A),
      Color(0xFF5B8DD6),
      Color(0xFF8E6AD8),
      Color(0xFFE06A8A),
    ];
    final seed = petName.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return colors[seed % colors.length];
  }

  static _PetKind _petKind(Map<String, dynamic>? pet, String? breed) {
    final species = [pet?['type'], pet?['species'], pet?['petType'], breed]
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .join(' ');

    if (species.contains('cat') ||
        species.contains('siamese') ||
        species.contains('shorthair') ||
        species.contains('maine coon') ||
        species.contains('ragdoll') ||
        species.contains('tabby')) {
      return _PetKind.cat;
    }
    return _PetKind.dog;
  }

  static String? _reimbursementFromCopay(Object? raw) {
    if (raw is num) return '${(100 - raw).round()}%';
    if (raw is String) {
      final parsed = num.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return '${(100 - parsed).round()}%';
    }
    return null;
  }

  static String _formatMoneyValue(Object value) {
    if (value is num) return '\$${value.toStringAsFixed(0)}';
    final text = value.toString().trim();
    if (text.startsWith(r'$')) return text;
    final parsed = num.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    return parsed == null ? text : '\$${parsed.toStringAsFixed(0)}';
  }

  static String _formatPercentValue(Object value) {
    if (value is num) return '${value.toStringAsFixed(0)}%';
    final text = value.toString().trim();
    if (text.endsWith('%')) return text;
    final parsed = num.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    return parsed == null ? text : '${parsed.toStringAsFixed(0)}%';
  }

  static int? _policyExclusionsCount(Map<String, dynamic> data) {
    final direct = data['exclusions'];
    if (direct is List) return direct.length;

    final snapshot = data['underwritingSnapshot'];
    if (snapshot is Map) {
      final decision = snapshot['decision'];
      if (decision is Map) {
        final exclusions = decision['exclusions'];
        if (exclusions is List) return exclusions.length;
      }
    }

    final plan = data['plan'];
    if (plan is Map) {
      final planExclusions = plan['exclusions'];
      if (planExclusions is List) return planExclusions.length;
    }

    return null;
  }

  static String _humanizeStatus(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Pending';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  void _handleSignOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    if (!redirectToMarketingSite(path: '/')) {
      context.go('/sign-in');
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

class _PortalBackdrop extends StatelessWidget {
  const _PortalBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF4), Color(0xFFF6FBF8), Color(0xFFFFF7EA)],
        ),
      ),
      child: CustomPaint(painter: _PortalBackdropPainter()),
    );
  }
}

class _PortalBackdropPainter extends CustomPainter {
  const _PortalBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFB9E4D1).withOpacity(0.18);
    canvas.drawCircle(Offset(size.width * 0.14, 110), 150, paint);

    paint.color = const Color(0xFFFFD59A).withOpacity(0.2);
    canvas.drawCircle(Offset(size.width * 0.92, 180), 190, paint);

    paint.color = const Color(0xFFBBD6FF).withOpacity(0.13);
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.66),
      220,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _PetKind { dog, cat }

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({
    required this.name,
    required this.kind,
    required this.color,
    this.size = 56,
  });

  final String name;
  final _PetKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name ${kind == _PetKind.cat ? 'cat' : 'dog'} avatar',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PetAvatarPainter(kind: kind, color: color),
        ),
      ),
    );
  }
}

class _PetAvatarPainter extends CustomPainter {
  const _PetAvatarPainter({required this.kind, required this.color});

  final _PetKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.045;

    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.width * 0.26),
      ),
      paint,
    );

    paint.color = color.withOpacity(0.13);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.42, paint);

    if (kind == _PetKind.cat) {
      _paintCat(canvas, size, paint, stroke);
    } else {
      _paintDog(canvas, size, paint, stroke);
    }
  }

  void _paintDog(Canvas canvas, Size size, Paint paint, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    paint.color = const Color(0xFFFFD59A);
    canvas.drawCircle(center, w * 0.26, paint);
    paint.color = color.withOpacity(0.82);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.25, w * 0.18, h * 0.36),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.64, h * 0.25, w * 0.18, h * 0.36),
      paint,
    );
    paint.color = const Color(0xFFFFE4B8);
    canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.17, paint);
    paint.color = AppColors.text;
    canvas.drawCircle(Offset(w * 0.41, h * 0.46), w * 0.035, paint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.46), w * 0.035, paint);
    paint.color = const Color(0xFF744C2B);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.56),
        width: w * 0.13,
        height: h * 0.09,
      ),
      paint,
    );
  }

  void _paintCat(Canvas canvas, Size size, Paint paint, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final head = Path()
      ..moveTo(w * 0.25, h * 0.42)
      ..lineTo(w * 0.34, h * 0.18)
      ..lineTo(w * 0.48, h * 0.35)
      ..lineTo(w * 0.64, h * 0.18)
      ..lineTo(w * 0.76, h * 0.42)
      ..quadraticBezierTo(w * 0.76, h * 0.78, w * 0.5, h * 0.78)
      ..quadraticBezierTo(w * 0.24, h * 0.78, w * 0.25, h * 0.42)
      ..close();

    paint.color = const Color(0xFFFFC77D);
    canvas.drawPath(head, paint);
    paint.color = color.withOpacity(0.8);
    canvas.drawCircle(Offset(w * 0.41, h * 0.48), w * 0.035, paint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.48), w * 0.035, paint);
    paint.color = AppColors.green;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.58),
        width: w * 0.11,
        height: h * 0.08,
      ),
      paint,
    );
    stroke.color = AppColors.textMuted.withOpacity(0.7);
    stroke.strokeWidth = w * 0.024;
    canvas.drawLine(
      Offset(w * 0.45, h * 0.61),
      Offset(w * 0.26, h * 0.56),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.45, h * 0.64),
      Offset(w * 0.25, h * 0.66),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.55, h * 0.61),
      Offset(w * 0.74, h * 0.56),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.55, h * 0.64),
      Offset(w * 0.75, h * 0.66),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PetAvatarPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

class _FloatingPortalIllustration extends StatelessWidget {
  const _FloatingPortalIllustration({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final offset = -6 + (controller.value * 12);
          return Transform.translate(
            offset: Offset(0, offset),
            child: Transform.rotate(
              angle: -0.025 + (controller.value * 0.05),
              child: child,
            ),
          );
        },
        child: const SizedBox(
          width: 190,
          height: 170,
          child: CustomPaint(painter: _PortalPetFamilyPainter()),
        ),
      ),
    );
  }
}

class _PortalPetFamilyPainter extends CustomPainter {
  const _PortalPetFamilyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    paint.color = const Color(0xFFFFFFFF).withOpacity(0.92);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 28, size.width - 24, size.height - 34),
        const Radius.circular(34),
      ),
      paint,
    );

    paint.color = const Color(0xFFFFD59A);
    canvas.drawCircle(Offset(size.width * 0.36, 86), 46, paint);
    paint.color = const Color(0xFFE9A857);
    canvas.drawOval(Rect.fromLTWH(42, 52, 28, 46), paint);
    canvas.drawOval(Rect.fromLTWH(94, 52, 28, 46), paint);
    paint.color = const Color(0xFFFFE1AE);
    canvas.drawCircle(Offset(size.width * 0.36, 91), 31, paint);
    paint.color = AppColors.text;
    canvas.drawCircle(Offset(size.width * 0.28, 82), 4, paint);
    canvas.drawCircle(Offset(size.width * 0.43, 82), 4, paint);
    paint.color = const Color(0xFF7C4F25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.36, 96),
        width: 13,
        height: 9,
      ),
      paint,
    );
    stroke.color = const Color(0xFFE9A857);
    canvas.drawArc(Rect.fromLTWH(30, 84, 54, 54), 2.7, 1.1, false, stroke);

    paint.color = const Color(0xFFB9E4D1);
    canvas.drawOval(Rect.fromLTWH(108, 70, 54, 70), paint);
    paint.color = const Color(0xFFD8F3DC);
    canvas.drawCircle(Offset(size.width * 0.72, 75), 34, paint);
    final earPath = Path()
      ..moveTo(126, 48)
      ..lineTo(140, 24)
      ..lineTo(152, 52)
      ..close();
    paint.color = const Color(0xFFB9E4D1);
    canvas.drawPath(earPath, paint);
    final earPath2 = Path()
      ..moveTo(154, 50)
      ..lineTo(170, 29)
      ..lineTo(174, 60)
      ..close();
    canvas.drawPath(earPath2, paint);
    paint.color = AppColors.text;
    canvas.drawCircle(Offset(size.width * 0.66, 70), 3.5, paint);
    canvas.drawCircle(Offset(size.width * 0.77, 70), 3.5, paint);
    paint.color = AppColors.green;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.72, 82),
        width: 10,
        height: 7,
      ),
      paint,
    );
    stroke.color = const Color(0xFF2D8F73);
    stroke.strokeWidth = 2;
    canvas.drawLine(const Offset(138, 84), const Offset(120, 78), stroke);
    canvas.drawLine(const Offset(140, 87), const Offset(120, 88), stroke);
    canvas.drawLine(const Offset(148, 84), const Offset(166, 78), stroke);
    canvas.drawLine(const Offset(146, 87), const Offset(166, 88), stroke);

    paint.color = const Color(0xFF2D8F73).withOpacity(0.14);
    canvas.drawCircle(Offset(size.width * 0.22, 132), 5, paint);
    canvas.drawCircle(Offset(size.width * 0.83, 128), 5, paint);
    canvas.drawCircle(Offset(size.width * 0.52, 38), 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final titleStyle = GoogleFonts.playfairDisplay(
      color: AppColors.text,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

    final subtitleStyle = GoogleFonts.dmSans(
      color: AppColors.textSubtle,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w500,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: AppRadii.br20,
        border: Border.all(color: const Color(0xFFDCE8E0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF126B4D).withOpacity(0.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
    final titleStyle = GoogleFonts.dmSans(
      color: enabled ? AppColors.deepGreen : AppColors.textSubtle,
      fontWeight: FontWeight.w700,
      fontSize: 15.5,
    );

    final subtitleStyle = GoogleFonts.dmSans(
      color: enabled ? AppColors.textMuted : AppColors.textSubtle,
      fontWeight: FontWeight.w500,
      fontSize: 13.5,
      height: 1.35,
    );

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.br16,
      child: InkWell(
        borderRadius: AppRadii.br16,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.br16,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
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
                    Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: subtitleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.dmSans(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w700,
      fontSize: 15.5,
    );

    final subtitleStyle = GoogleFonts.dmSans(
      color: AppColors.textSubtle,
      height: 1.3,
      fontWeight: FontWeight.w500,
      fontSize: 13.5,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.br16,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.br16,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(0.08)],
            ),
            borderRadius: AppRadii.br16,
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(icon, color: color, size: 22),
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
              Icon(Icons.arrow_forward, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBrief extends StatelessWidget {
  const _StatusBrief({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withOpacity(0.09)],
        ),
        borderRadius: AppRadii.br16,
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSubtle,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyFact extends StatelessWidget {
  const _PolicyFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppColors.textSubtle,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyControlData {
  const _PolicyControlData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
}

class _PolicyControlsGrid extends StatelessWidget {
  const _PolicyControlsGrid({required this.items});

  final List<_PolicyControlData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width = (constraints.maxWidth - (10 * (columns - 1))) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _PolicyControl(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PolicyControl extends StatelessWidget {
  const _PolicyControl({required this.item});

  final _PolicyControlData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: AppRadii.br12,
        border: Border.all(color: item.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 18),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: GoogleFonts.dmSans(
              color: AppColors.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: AppColors.text,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  const _PortalBadge({
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.surface2,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.green),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalEmptyState extends StatelessWidget {
  const _PortalEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSubtle,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalSkeleton extends StatelessWidget {
  const _PortalSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _PortalSection(
      title: title,
      subtitle: 'Loading your latest account details.',
      child: const LinearProgressIndicator(minHeight: 3),
    );
  }
}

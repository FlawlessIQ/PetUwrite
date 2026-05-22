import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checkout_state.dart';
import '../services/policy_service.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/tokens.dart';
import 'claims/claim_details_screen.dart';
import 'claims/claim_intake_screen.dart';

class PolicyDetailsScreen extends StatefulWidget {
  const PolicyDetailsScreen({
    super.key,
    required this.policyId,
    required this.initialData,
  });

  final String policyId;
  final Map<String, dynamic> initialData;

  @override
  State<PolicyDetailsScreen> createState() => _PolicyDetailsScreenState();
}

class _PolicyDetailsScreenState extends State<PolicyDetailsScreen> {
  final PolicyService _policyService = PolicyService();
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('policies')
              .doc(widget.policyId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = {
              ...widget.initialData,
              if (snapshot.data?.data() != null) ...snapshot.data!.data()!,
              'policyId': widget.policyId,
            };

            if (snapshot.hasError) {
              return _PolicyDetailsShell(
                child: _PolicyErrorState(message: '${snapshot.error}'),
              );
            }

            return _PolicyDetailsShell(
              child: _buildPolicyContent(context, data),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPolicyContent(
    BuildContext context,
    Map<String, dynamic> policy,
  ) {
    final pet = _asMap(policy['pet']);
    final plan = _asMap(policy['plan']);
    final payment = _asMap(policy['payment']);
    final petName = _text(pet, ['name']) ?? 'Your pet';
    final petBreed = _text(pet, ['breed']) ?? 'Pet';
    final planName = _text(plan, ['name']) ?? 'Coverage plan';
    final policyNumber = _text(policy, ['policyNumber']) ?? widget.policyId;
    final status = _text(policy, ['status']) ?? 'active';
    final monthlyPremium =
        _numValue(plan, ['monthlyPremium']) ??
        _numValue(policy, ['monthlyPremium', 'premiumAmount']);
    final deductible =
        _numValue(plan, ['annualDeductible', 'deductible']) ??
        _numValue(policy, ['deductible']);
    final reimbursement = _reimbursementPercent(policy);
    final annualLimit = _annualLimit(plan);
    final effectiveDate = _parseDate(policy['effectiveDate']);
    final expirationDate = _parseDate(policy['expirationDate']);
    final exclusions = _exclusionsFrom(policy);
    final features = _stringList(plan?['features']);
    final addOns = _stringList(plan?['selectedAddOns']);
    final waitingPeriods = _asMap(plan?['waitingPeriodsDays']);
    final paymentStatus =
        _text(payment, ['status']) ??
        _text(policy, ['billingStatus', 'paymentStatus']) ??
        'on file';
    final last4 = _text(payment, ['last4'], fallback: null);
    final brand = _text(payment, ['brand'], fallback: null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(context),
        const SizedBox(height: 22),
        _PolicyHeroCard(
          petName: petName,
          petBreed: petBreed,
          planName: planName,
          policyNumber: policyNumber,
          status: status,
          monthlyPremium: monthlyPremium,
          effectiveDate: effectiveDate,
          expirationDate: expirationDate,
        ),
        const SizedBox(height: 16),
        _PolicyActionRail(
          isDownloading: _isDownloading,
          onFileClaim: () => _startClaim(context, policy),
          onDownloadPolicy: () => _downloadPolicy(context, policy),
          onContactSupport: () => _showSupportDialog(context),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 940;
            final left = Column(
              children: [
                _PolicySectionCard(
                  eyebrow: 'Coverage',
                  title: 'What is active',
                  child: _PolicyFactsGrid(
                    facts: [
                      _PolicyFactData(
                        label: 'Monthly',
                        value: monthlyPremium == null
                            ? 'On file'
                            : '\$${monthlyPremium.toStringAsFixed(0)}/mo',
                      ),
                      _PolicyFactData(
                        label: 'Deductible',
                        value: deductible == null
                            ? 'On file'
                            : '\$${deductible.toStringAsFixed(0)}',
                      ),
                      _PolicyFactData(
                        label: 'Reimbursement',
                        value: reimbursement == null
                            ? 'On file'
                            : '$reimbursement%',
                      ),
                      _PolicyFactData(
                        label: 'Annual limit',
                        value: annualLimit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PolicySectionCard(
                  eyebrow: 'Terms',
                  title: 'Waiting periods',
                  child: _WaitingPeriodsList(waitingPeriods: waitingPeriods),
                ),
                const SizedBox(height: 16),
                _PolicySectionCard(
                  eyebrow: 'Benefits',
                  title: 'Included in this plan',
                  child: _BulletList(
                    emptyText:
                        'Core accident and illness benefits are attached to this policy.',
                    items: [
                      if (features.isEmpty) ...[
                        'Accidents and illness',
                        'Emergency care',
                        'Specialist visits',
                      ] else
                        ...features,
                      ...addOns.map((addOn) => 'Add-on: ${_humanize(addOn)}'),
                    ],
                  ),
                ),
              ],
            );

            final right = Column(
              children: [
                _PolicySectionCard(
                  eyebrow: 'Documents',
                  title: 'Policy packet',
                  child: _DocumentsList(
                    isDownloading: _isDownloading,
                    onDownloadPolicy: () => _downloadPolicy(context, policy),
                    hasExclusions: exclusions.isNotEmpty,
                  ),
                ),
                const SizedBox(height: 16),
                _PolicySectionCard(
                  eyebrow: 'Billing',
                  title: 'Payment status',
                  child: _BillingSummary(
                    monthlyPremium: monthlyPremium,
                    paymentStatus: paymentStatus,
                    brand: brand,
                    last4: last4,
                    renewalDate: expirationDate,
                  ),
                ),
                const SizedBox(height: 16),
                _PolicySectionCard(
                  eyebrow: 'Exclusions',
                  title: exclusions.isEmpty
                      ? 'No listed exclusions'
                      : '${exclusions.length} listed',
                  child: _ExclusionsList(exclusions: exclusions),
                ),
              ],
            );

            if (!isDesktop) {
              return Column(
                children: [left, const SizedBox(height: 16), right],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: left),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: right),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _PolicySectionCard(
          eyebrow: 'Claims',
          title: '$petName claim history',
          trailing: TextButton.icon(
            onPressed: () => _startClaim(context, policy),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('File a claim'),
          ),
          child: _PolicyClaimsList(policyId: widget.policyId),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        const SizedBox(width: 12),
        const ClovaraLogo(size: ClovaraLogoSize.small, showText: true),
      ],
    );
  }

  Future<void> _downloadPolicy(
    BuildContext context,
    Map<String, dynamic> policy,
  ) async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);
    try {
      final policyDocument = _policyDocumentFrom(policy, widget.policyId);
      final pdfUrl = await _policyService.generatePolicyPDF(policyDocument);
      final uri = Uri.tryParse(pdfUrl);
      if (uri == null) {
        throw Exception('The generated policy link was invalid.');
      }

      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened) {
        throw Exception('Unable to open the generated policy PDF.');
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Policy PDF opened.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Policy PDF is not available yet: $e'),
          backgroundColor: AppColors.warning,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _startClaim(BuildContext context, Map<String, dynamic> policy) {
    final pet = _asMap(policy['pet']);
    final petId =
        _text(pet, ['id', 'petId'], fallback: null) ??
        _text(policy, ['petId'], fallback: null);

    if (petId == null || petId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This policy is missing the pet ID needed to file a claim.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimIntakeScreen(
          policyId: widget.policyId,
          petId: petId,
          ignoreExistingDrafts: true,
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need help?'),
        content: const Text(
          'Email support@clovara.com and include your policy number. We will help with documents, billing, claims, or account access.',
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

  static PolicyDocument _policyDocumentFrom(
    Map<String, dynamic> data,
    String policyId,
  ) {
    final json = Map<String, dynamic>.from(data);
    json['policyId'] = _text(json, ['policyId'], fallback: policyId);
    json['effectiveDate'] =
        _parseDate(json['effectiveDate'])?.toIso8601String() ??
        DateTime.now().toIso8601String();
    json['expirationDate'] =
        _parseDate(json['expirationDate'])?.toIso8601String() ??
        DateTime.now().add(const Duration(days: 365)).toIso8601String();
    json['createdAt'] =
        _parseDate(json['createdAt'])?.toIso8601String() ??
        DateTime.now().toIso8601String();

    final payment = _asMap(json['payment']);
    if (payment != null) {
      final paidAt = _parseDate(payment['paidAt']);
      if (paidAt != null) {
        json['payment'] = {...payment, 'paidAt': paidAt.toIso8601String()};
      }
    }

    final exclusions = json['exclusions'];
    if (exclusions is List) {
      json['exclusions'] = exclusions
          .whereType<Map>()
          .map((entry) {
            final mapped = entry.cast<String, dynamic>();
            final effectiveDate = _parseDate(mapped['effectiveDate']);
            return {
              ...mapped,
              'effectiveDate':
                  effectiveDate?.toIso8601String() ??
                  DateTime.now().toIso8601String(),
            };
          })
          .toList(growable: false);
    }

    return PolicyDocument.fromJson(json);
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static String? _text(
    Map<String, dynamic>? data,
    List<String> keys, {
    String? fallback,
  }) {
    if (data == null) return fallback;
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  static num? _numValue(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is String) return DateTime.tryParse(raw.trim());
    return null;
  }

  static int? _reimbursementPercent(Map<String, dynamic> policy) {
    final plan = _asMap(policy['plan']);
    final direct =
        _numValue(plan, ['reimbursementPercent', 'reimbursement']) ??
        _numValue(policy, ['reimbursementPercent', 'reimbursement']);
    if (direct != null) return direct.round();

    final coPay = _numValue(plan, ['coPayPercentage']);
    if (coPay != null) return (100 - coPay).round();
    return null;
  }

  static String _annualLimit(Map<String, dynamic>? plan) {
    if (plan?['isUnlimitedAnnualCoverage'] == true) return 'Unlimited';
    final limit = _numValue(plan, ['maxAnnualCoverage', 'annualLimit']);
    if (limit == null || limit <= 0) return 'On file';
    if (limit >= 1000000) {
      return '\$${(limit / 1000000).toStringAsFixed(1)}M';
    }
    if (limit >= 1000) {
      return '\$${(limit / 1000).toStringAsFixed(0)}K';
    }
    return '\$${limit.toStringAsFixed(0)}';
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static List<_PolicyExclusionData> _exclusionsFrom(
    Map<String, dynamic> policy,
  ) {
    final direct = policy['exclusions'];
    final exclusions = <_PolicyExclusionData>[];

    void collect(Object? value) {
      if (value is! List) return;
      for (final entry in value) {
        if (entry is Map) {
          final mapped = entry.cast<String, dynamic>();
          final name = _text(mapped, [
            'conditionName',
            'condition',
            'name',
            'label',
          ], fallback: null);
          if (name == null) continue;
          exclusions.add(
            _PolicyExclusionData(
              title: name,
              scope: _humanize(
                _text(mapped, ['scope'], fallback: 'condition')!,
              ),
              notes: _text(mapped, ['notes', 'reason'], fallback: null),
              effectiveDate: _parseDate(mapped['effectiveDate']),
            ),
          );
        } else {
          final text = entry.toString().trim();
          if (text.isNotEmpty) {
            exclusions.add(
              _PolicyExclusionData(title: text, scope: 'Policy term'),
            );
          }
        }
      }
    }

    collect(direct);

    final snapshot = _asMap(policy['underwritingSnapshot']);
    final decision = _asMap(snapshot?['decision']);
    collect(decision?['exclusions']);

    final plan = _asMap(policy['plan']);
    collect(plan?['exclusions']);

    final byTitle = <String, _PolicyExclusionData>{};
    for (final item in exclusions) {
      byTitle[item.title.toLowerCase()] = item;
    }
    return byTitle.values.toList(growable: false);
  }

  static String _humanize(String value) {
    final cleaned = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
    if (cleaned.isEmpty) return value;
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _PolicyDetailsShell extends StatelessWidget {
  const _PolicyDetailsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
      child: MaxWidth(maxWidth: 1120, child: child),
    );
  }
}

class _PolicyHeroCard extends StatelessWidget {
  const _PolicyHeroCard({
    required this.petName,
    required this.petBreed,
    required this.planName,
    required this.policyNumber,
    required this.status,
    required this.monthlyPremium,
    required this.effectiveDate,
    required this.expirationDate,
  });

  final String petName;
  final String petBreed;
  final String planName;
  final String policyNumber;
  final String status;
  final num? monthlyPremium;
  final DateTime? effectiveDate;
  final DateTime? expirationDate;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    final titleStyle = GoogleFonts.playfairDisplay(
      color: AppColors.text,
      fontWeight: FontWeight.w700,
      fontSize: 44,
      height: 0.98,
      letterSpacing: -0.9,
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br24,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final petBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PolicyPill(
                label: _humanize(status),
                color: statusColor,
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: 16),
              Text('$petName is covered.', style: titleStyle),
              const SizedBox(height: 10),
              Text(
                '$planName coverage for $petBreed. Policy #$policyNumber.',
                style: GoogleFonts.dmSans(
                  color: AppColors.textSubtle,
                  fontSize: 16,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

          final premiumBlock = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadii.br20,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONTHLY',
                  style: GoogleFonts.dmSans(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  monthlyPremium == null
                      ? 'On file'
                      : '\$${monthlyPremium!.toStringAsFixed(0)}/mo',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _MiniDateRow(label: 'Effective', date: effectiveDate),
                const SizedBox(height: 8),
                _MiniDateRow(label: 'Renews', date: expirationDate),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [petBlock, const SizedBox(height: 18), premiumBlock],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: petBlock),
              const SizedBox(width: 24),
              SizedBox(width: 260, child: premiumBlock),
            ],
          );
        },
      ),
    );
  }

  static Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('active')) return AppColors.success;
    if (normalized.contains('cancel') || normalized.contains('expired')) {
      return AppColors.danger;
    }
    return AppColors.warning;
  }

  static String _humanize(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Status';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _PolicyActionRail extends StatelessWidget {
  const _PolicyActionRail({
    required this.isDownloading,
    required this.onFileClaim,
    required this.onDownloadPolicy,
    required this.onContactSupport,
  });

  final bool isDownloading;
  final VoidCallback onFileClaim;
  final VoidCallback onDownloadPolicy;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final actions = [
          _PolicyActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'File a claim',
            onPressed: onFileClaim,
            isPrimary: true,
          ),
          _PolicyActionButton(
            icon: Icons.description_outlined,
            label: isDownloading ? 'Generating...' : 'Download policy',
            onPressed: isDownloading ? null : onDownloadPolicy,
          ),
          _PolicyActionButton(
            icon: Icons.support_agent_outlined,
            label: 'Get help',
            onPressed: onContactSupport,
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions
                .map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: action,
                  ),
                )
                .toList(growable: false),
          );
        }

        return Row(
          children: actions
              .map(
                (action) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: action,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PolicyActionButton extends StatelessWidget {
  const _PolicyActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepGreen,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br20,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.text,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PolicyFactData {
  const _PolicyFactData({required this.label, required this.value});

  final String label;
  final String value;
}

class _PolicyFactsGrid extends StatelessWidget {
  const _PolicyFactsGrid({required this.facts});

  final List<_PolicyFactData> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - (10 * (columns - 1))) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map(
                (fact) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadii.br16,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact.label.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            color: AppColors.textSubtle,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fact.value,
                          style: GoogleFonts.dmSans(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({
    required this.isDownloading,
    required this.onDownloadPolicy,
    required this.hasExclusions,
  });

  final bool isDownloading;
  final VoidCallback onDownloadPolicy;
  final bool hasExclusions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DocumentRow(
          title: 'Policy packet',
          subtitle: 'Declarations, coverage terms, and plan details.',
          actionLabel: isDownloading ? 'Generating' : 'Download',
          onTap: isDownloading ? null : onDownloadPolicy,
        ),
        const SizedBox(height: 10),
        _DocumentRow(
          title: 'Coverage summary',
          subtitle: 'A plain-English snapshot of the active plan.',
          actionLabel: isDownloading ? 'Generating' : 'Download',
          onTap: isDownloading ? null : onDownloadPolicy,
        ),
        const SizedBox(height: 10),
        _DocumentRow(
          title: 'Exclusions addendum',
          subtitle: hasExclusions
              ? 'Conditions or terms that are not covered.'
              : 'No listed exclusions are attached to this policy.',
          actionLabel: hasExclusions ? 'Download' : 'Clear',
          onTap: hasExclusions && !isDownloading ? onDownloadPolicy : null,
        ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br16,
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
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.green,
            ),
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
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _BillingSummary extends StatelessWidget {
  const _BillingSummary({
    required this.monthlyPremium,
    required this.paymentStatus,
    required this.brand,
    required this.last4,
    required this.renewalDate,
  });

  final num? monthlyPremium;
  final String paymentStatus;
  final String? brand;
  final String? last4;
  final DateTime? renewalDate;

  @override
  Widget build(BuildContext context) {
    final method = last4 == null
        ? 'Payment method on file'
        : '${brand == null ? 'Card' : _humanize(brand!)} ending $last4';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BillingRow(
          icon: Icons.payments_outlined,
          label: 'Amount',
          value: monthlyPremium == null
              ? 'On file'
              : '\$${monthlyPremium!.toStringAsFixed(2)} monthly',
        ),
        const SizedBox(height: 10),
        _BillingRow(
          icon: Icons.credit_card_outlined,
          label: 'Method',
          value: method,
        ),
        const SizedBox(height: 10),
        _BillingRow(
          icon: Icons.verified_outlined,
          label: 'Status',
          value: _humanize(paymentStatus),
        ),
        const SizedBox(height: 10),
        _BillingRow(
          icon: Icons.event_available_outlined,
          label: 'Renewal',
          value: renewalDate == null
              ? 'On file'
              : DateFormat.yMMMd().format(renewalDate!),
        ),
      ],
    );
  }

  static String _humanize(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'On file';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.textSubtle,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: AppColors.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WaitingPeriodsList extends StatelessWidget {
  const _WaitingPeriodsList({required this.waitingPeriods});

  final Map<String, dynamic>? waitingPeriods;

  @override
  Widget build(BuildContext context) {
    final rows = <_WaitingRowData>[
      _WaitingRowData(
        label: 'Accidents',
        value: _waitingValue('accident') ?? 'Day 1',
      ),
      _WaitingRowData(
        label: 'Illness',
        value: _waitingValue('illness') ?? '14 days',
      ),
      _WaitingRowData(
        label: 'Orthopedic',
        value: _waitingValue('orthopedic') ?? 'See policy',
      ),
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BillingRow(
                icon: Icons.schedule_outlined,
                label: row.label,
                value: row.value,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String? _waitingValue(String key) {
    final raw = waitingPeriods?[key] ?? waitingPeriods?['${key}Days'];
    if (raw == null) return null;
    if (raw is num) return raw == 0 ? 'Day 1' : '${raw.toInt()} days';
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class _WaitingRowData {
  const _WaitingRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.emptyText});

  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final entries = items.isEmpty ? [emptyText] : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSubtle,
                        height: 1.45,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ExclusionsList extends StatelessWidget {
  const _ExclusionsList({required this.exclusions});

  final List<_PolicyExclusionData> exclusions;

  @override
  Widget build(BuildContext context) {
    if (exclusions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F0),
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No condition-specific exclusions are listed on this policy. Standard policy terms still apply.',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: exclusions
          .map(
            (exclusion) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadii.br16,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.block_outlined,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exclusion.title,
                          style: GoogleFonts.dmSans(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      exclusion.scope,
                      if (exclusion.effectiveDate != null)
                        'effective ${DateFormat.yMMMd().format(exclusion.effectiveDate!)}',
                    ].join(' • '),
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSubtle,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (exclusion.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      exclusion.notes!,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSubtle,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PolicyClaimsList extends StatelessWidget {
  const _PolicyClaimsList({required this.policyId});

  final String policyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('policyId', isEqualTo: policyId)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _InlineNotice(
            icon: Icons.error_outline,
            title: 'Claims unavailable',
            body: '${snapshot.error}',
            color: AppColors.warning,
          );
        }

        final docs = [...(snapshot.data?.docs ?? const [])];
        docs.sort((a, b) {
          final ad = _parseDate(a.data()['updatedAt']);
          final bd = _parseDate(b.data()['updatedAt']);
          return (bd ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            ad ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
        });

        if (docs.isEmpty) {
          return const _InlineNotice(
            icon: Icons.receipt_long_outlined,
            title: 'No claims yet',
            body:
                'When care happens, start a claim from this policy and track every step here.',
            color: AppColors.green,
          );
        }

        return Column(
          children: docs
              .map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClaimHistoryRow(claimId: doc.id, data: doc.data()),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class _ClaimHistoryRow extends StatelessWidget {
  const _ClaimHistoryRow({required this.claimId, required this.data});

  final String claimId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final type = (data['claimType'] ?? data['description'] ?? 'Claim')
        .toString()
        .trim();
    final status = (data['status'] ?? 'pending').toString();
    final amount = data['claimAmount'] is num
        ? data['claimAmount'] as num
        : data['approvedAmount'] is num
        ? data['approvedAmount'] as num
        : null;
    final updatedAt = _parseDate(data['updatedAt']);
    final statusColor = _statusColor(status);

    return Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.br16,
      child: InkWell(
        borderRadius: AppRadii.br16,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClaimDetailsScreen(claimId: claimId),
            ),
          );
        },
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.receipt_long_outlined, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.isEmpty ? 'Claim' : _humanize(type),
                      style: GoogleFonts.dmSans(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      updatedAt == null
                          ? _humanize(status)
                          : '${_humanize(status)} • Updated ${DateFormat.MMMd().format(updatedAt)}',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSubtle,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: 10),
                Text(
                  '\$${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSubtle),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('paid') ||
        normalized.contains('approved') ||
        normalized.contains('settled')) {
      return AppColors.success;
    }
    if (normalized.contains('denied') || normalized.contains('reject')) {
      return AppColors.danger;
    }
    return AppColors.warning;
  }

  static String _humanize(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Claim';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
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
        color: color.withOpacity(0.08),
        borderRadius: AppRadii.br16,
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSubtle,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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

class _PolicyPill extends StatelessWidget {
  const _PolicyPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDateRow extends StatelessWidget {
  const _MiniDateRow({required this.label, required this.date});

  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          date == null ? 'On file' : DateFormat.MMMd().format(date!),
          style: GoogleFonts.dmSans(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _PolicyExclusionData {
  const _PolicyExclusionData({
    required this.title,
    required this.scope,
    this.notes,
    this.effectiveDate,
  });

  final String title;
  final String scope;
  final String? notes;
  final DateTime? effectiveDate;
}

class _PolicyErrorState extends StatelessWidget {
  const _PolicyErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.br20,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Unable to load policy details: $message',
          style: GoogleFonts.dmSans(color: AppColors.textSubtle, height: 1.5),
        ),
      ),
    );
  }
}

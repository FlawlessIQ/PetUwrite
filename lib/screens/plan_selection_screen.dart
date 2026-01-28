import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/risk_score.dart';
import '../models/owner.dart';
import '../models/underwriting_exclusion.dart';
import '../models/pet.dart';
import '../services/quote_engine.dart';
import '../services/product_catalog.dart';
import '../services/draft_service.dart';
import '../services/product_catalog_availability_engine.dart';
import '../services/pricing_quote_service.dart';
import '../services/pricing_gate.dart';
import '../theme/clovara_theme.dart';
import '../ui/tokens.dart';
import '../ui/components/checkout_ui/checkout_card.dart';
import '../ui/components/save_resume_dialog.dart';
import '../services/user_session_service.dart';

/// Minimal, clean plan selection screen
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  int _selectedPlanIndex = 1;
  Map<String, dynamic>? _routeArguments;
  List<Plan>? _dynamicPlans;
  bool _isLoadingPlans = true;
  bool _pricingAllowed = false;
  String _pricingBlockReason = 'UNDERWRITING_INCOMPLETE';

  // Mobile plan carousel controller.
  final PageController _mobilePlanController = PageController(
    viewportFraction: 0.92,
  );

  final DraggableScrollableController _customizerController =
      DraggableScrollableController();

  // Track baseline premium for delta display when customizing.
  double? _baselineMonthlyPremium;

  // Compare plans UI state (kept local inside modal/dialog, but this is the default).
  bool _comparePinSelectedDefault = true;

  final ProductCatalogAvailabilityEngine _productAvailability =
      ProductCatalogAvailabilityEngine();
  Map<String, dynamic>? _availability;
  bool _isLoadingAvailability = true;

  List<String> _getExclusionNamesFromRoute() {
    final raw =
        _routeArguments?['exclusions'] ??
        _routeArguments?['excludedConditions'];
    if (raw == null) return const [];

    final names = <String>[];

    void addName(String? value) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) return;
      if (!names.contains(trimmed)) names.add(trimmed);
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          addName(item);
        } else if (item is UnderwritingExclusion) {
          // Format structured exclusions for chip display
          if (item.type == UnderwritingExclusionType.anomalyDerived && 
              item.scope.toLowerCase().contains('weight')) {
            addName('Weight Risk');
          } else if (item.type == UnderwritingExclusionType.breedLinked) {
            final label = item.scope.isNotEmpty ? item.scope : 'Breed Risk';
            addName('${label[0].toUpperCase()}${label.substring(1)} (Breed Linked)');
          } else {
             // Fallback to scope or explanation prefix
             addName(item.scope.isNotEmpty ? item.scope : 'Exclusion');
          }
        } else if (item is Map) {
          final conditionName = item['conditionName']?.toString();
          addName(conditionName);
        } else {
          // Best-effort fallback for unknown shapes
          addName(item.toString());
        }
      }
    } else if (raw is Map) {
      addName(raw['conditionName']?.toString());
    } else if (raw is String) {
      addName(raw);
    }

    return names;
  }

  Widget _buildExclusionsChips() {
    final exclusions = _getExclusionNamesFromRoute();
    if (exclusions.isEmpty) return const SizedBox.shrink();

    final chipFill = AppColors.accentAmber.withOpacity(0.16);
    final chipBorder = AppColors.accentAmber.withOpacity(0.9);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: exclusions
            .map(
              (e) => Chip(
                label: Text(
                  e,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                backgroundColor: chipFill,
                side: BorderSide(color: chipBorder, width: 1.2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildExclusionsCallout() {
    final exclusions = _getExclusionNamesFromRoute();
    if (exclusions.isEmpty) return const SizedBox.shrink();

    final bg = AppColors.accentAmber.withOpacity(0.16);
    final border = AppColors.accentAmber.withOpacity(0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadii.br16,
            border: Border.all(color: border, width: 1.6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.28),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Important: coverage exclusions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "This policy won’t cover treatment related to the conditions below.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These exclusions apply regardless of which plan you pick.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildExclusionsChips(),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  @override
  void dispose() {
    _mobilePlanController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    try {
      final availability = await _productAvailability.getAvailability();
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _isLoadingAvailability = false;
      });

      // If plans are already present, re-filter them.
      if (_dynamicPlans != null && _dynamicPlans!.isNotEmpty) {
        _applyAvailabilityToPlans();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availability = null;
        _isLoadingAvailability = false;
      });
    }
  }

  List<Plan> _filterPlansByAvailability(List<Plan> plans) {
    final availability = _availability;
    final withoutUnlimited = plans
        .where((p) => p.type != PlanType.unlimited)
        .toList();
    if (availability == null) return withoutUnlimited;
    return withoutUnlimited
        .where(
          (p) => ProductCatalogAvailabilityEngine.isTierEnabled(
            availability,
            p.type.name,
          ),
        )
        .toList();
  }

  void _applyAvailabilityToPlans() {
    if (_dynamicPlans == null) return;
    final filtered = _filterPlansByAvailability(_dynamicPlans!);
    if (filtered.isEmpty) return;

    // Keep selection stable if possible.
    final selected =
        (_selectedPlanIndex >= 0 && _selectedPlanIndex < _dynamicPlans!.length)
        ? _dynamicPlans![_selectedPlanIndex]
        : null;

    final nextIndex = selected == null
        ? 0
        : filtered.indexWhere((p) => p.type == selected.type);

    setState(() {
      _dynamicPlans = filtered;
      _selectedPlanIndex = nextIndex >= 0 ? nextIndex : 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArguments == null) {
      _routeArguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _generatePlans();
    }
  }

  void _generatePlans() {
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final owner = _routeArguments?['owner'] as Owner?;

    final approved = PricingGate.isPricingAllowed(_routeArguments);
    if (!approved) {
      setState(() {
        _pricingAllowed = false;
        _pricingBlockReason = PricingGate.blockReason(_routeArguments);
        _isLoadingPlans = false;
      });
      return;
    }

    _pricingAllowed = true;

    if (riskScore == null || owner == null) {
      setState(() => _isLoadingPlans = false);
      return;
    }

    final ageYears = _resolveAgeYearsFromRoute();

    Future<void> applyPlans(List<Plan> plans) async {
      final filtered = _filterPlansByAvailability(plans);
      if (filtered.isEmpty) {
        setState(() {
          _dynamicPlans = const <Plan>[];
          _isLoadingPlans = false;
        });
        return;
      }

      final recommendedPlanType =
          filtered.any((p) => p.type == PlanType.standard)
          ? PlanType.standard
          : filtered.first.type;
      final recommendedIndex = filtered.indexWhere(
        (p) => p.type == recommendedPlanType,
      );

      setState(() {
        _dynamicPlans = filtered;
        _isLoadingPlans = false;
        _selectedPlanIndex = recommendedIndex >= 0 ? recommendedIndex : 0;
        _baselineMonthlyPremium = filtered.isNotEmpty
            ? filtered[_selectedPlanIndex].monthlyPremium
            : null;
      });
    }

    () async {
      // Prefer server-side pricing (versioned).
      try {
        final svc = PricingQuoteService();
        final plans = await svc.getDayOnePlans(
          riskBand: riskScore.riskLevel.name,
          zipCode: owner.address.zipCode,
          state: owner.address.state,
          numberOfPets: 1,
          addOns: const <String>[],
        );

        await applyPlans(plans);
        return;
      } catch (_) {
        // Fall back to local pricing to keep UX unblocked.
      }

      try {
        final quoteEngine = QuoteEngine();
        final plans = quoteEngine.generateQuote(
          riskScore: riskScore,
          zipCode: owner.address.zipCode,
          state: owner.address.state,
          numberOfPets: 1,
          ageYears: ageYears,
        );
        await applyPlans(plans);
      } catch (e) {
        setState(() => _isLoadingPlans = false);
      }
    }();
  }

  Widget _buildPricingBlocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 44,
              color: AppColors.deepGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pricing is unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We need to complete underwriting before we can show plans or monthly premiums.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reason: $_pricingBlockReason',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepGreen,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAnnualLimit(Plan plan) {
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite)
      return 'Unlimited';
    return '\$${(plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}k';
  }

  void _updateSelectedPlan(Plan updated) {
    if (_dynamicPlans == null) return;
    setState(() {
      _dynamicPlans = List<Plan>.from(_dynamicPlans!);
      _dynamicPlans![_selectedPlanIndex] = updated;
    });
  }

  void _setSelectedPlanIndex(int index) {
    setState(() {
      _selectedPlanIndex = index;
      final selected = _plans[_selectedPlanIndex];
      if (selected is Plan) {
        _baselineMonthlyPremium = selected.monthlyPremium;
      } else {
        _baselineMonthlyPremium = (selected as PlanData).monthlyPrice;
      }
    });
  }

  Color _tierColor(dynamic plan) {
    if (plan is PlanData) return plan.color;
    if (plan is! Plan) return ClovaraColors.clover;
    switch (plan.type) {
      case PlanType.basic:
        return AppColors.textMuted;
      case PlanType.standard:
        return ClovaraColors.clover;
      case PlanType.plus:
        return AppColors.deepGreen;
      case PlanType.premium:
        return ClovaraColors.forest;
      case PlanType.unlimited:
        return ClovaraColors.forest;
    }
  }

  IconData _tierIcon(dynamic plan) {
    if (plan is PlanData) return Icons.shield_outlined;
    if (plan is! Plan) return Icons.shield_outlined;
    switch (plan.type) {
      case PlanType.basic:
        return Icons.shield_outlined;
      case PlanType.standard:
        return Icons.auto_awesome;
      case PlanType.plus:
        return Icons.stars;
      case PlanType.premium:
        return Icons.workspace_premium;
      case PlanType.unlimited:
        return Icons.security;
    }
  }

  String? _tierTagline(dynamic plan) {
    if (plan is PlanData) {
      if (plan.isPopular) return 'Best value';
      return null;
    }
    if (plan is! Plan) return null;
    switch (plan.type) {
      case PlanType.basic:
        return 'Great starter coverage';
      case PlanType.standard:
        return 'Best value';
      case PlanType.plus:
        return 'Higher protection';
      case PlanType.premium:
        return 'Maximize reimbursement';
      case PlanType.unlimited:
        return 'Unlimited peace of mind';
    }
  }

  void _openComparePlans({required bool isMobile}) {
    if (isMobile) {
      var pinSelected = _comparePinSelectedDefault;
      var workingSelectedIndex = _selectedPlanIndex;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: SingleChildScrollView(
                    child: _buildComparePlansContent(
                      isMobile: true,
                      selectedIndex: workingSelectedIndex,
                      pinSelected: pinSelected,
                      onTogglePinSelected: (next) {
                        setModalState(() => pinSelected = next);
                        _comparePinSelectedDefault = next;
                      },
                      onSelectIndex: (index) {
                        setModalState(() => workingSelectedIndex = index);
                        _setSelectedPlanIndex(index);
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return;
    }

    var pinSelected = _comparePinSelectedDefault;
    var workingSelectedIndex = _selectedPlanIndex;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Compare plans',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ClovaraColors.forest,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Close'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Side-by-side coverage and price — pick what fits your budget and risk tolerance.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildComparePlansContent(
                            isMobile: false,
                            selectedIndex: workingSelectedIndex,
                            pinSelected: pinSelected,
                            onTogglePinSelected: (next) {
                              setDialogState(() => pinSelected = next);
                              _comparePinSelectedDefault = next;
                            },
                            onSelectIndex: (index) {
                              setDialogState(
                                () => workingSelectedIndex = index,
                              );
                              _setSelectedPlanIndex(index);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparePlansContent({
    required bool isMobile,
    required int selectedIndex,
    required bool pinSelected,
    required void Function(bool next) onTogglePinSelected,
    required void Function(int index) onSelectIndex,
  }) {
    final plans = _plans;
    final labelWidth = isMobile ? 128.0 : 190.0;
    final colWidth = isMobile ? 170.0 : 210.0;

    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final recommendedIndex = riskScore == null
        ? null
        : _getRecommendedPlanIndex(riskScore, plans.length);

    String recommendationReason() {
      if (riskScore == null) return '';
      switch (riskScore.riskLevel) {
        case RiskLevel.low:
          return 'Lower risk → a balanced plan typically wins on value.';
        case RiskLevel.medium:
          return 'Medium risk → we recommend a strong mix of limit and price.';
        case RiskLevel.high:
        case RiskLevel.veryHigh:
          return 'Higher risk → prioritize higher reimbursement and annual limit.';
      }
    }

    String planName(dynamic plan) =>
        plan is Plan ? plan.name : (plan as PlanData).name;
    double planMonthly(dynamic plan) =>
        plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    int planDeductible(dynamic plan) => plan is Plan
        ? plan.annualDeductible.toInt()
        : (plan as PlanData).annualDeductible;
    int planReimburse(dynamic plan) => plan is Plan
        ? (100 - plan.coPayPercentage).toInt()
        : (plan as PlanData).reimbursement;
    String planLimit(dynamic plan) => plan is Plan
        ? _formatAnnualLimit(plan)
        : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    List<String> planFeatures(dynamic plan) =>
        plan is Plan ? plan.features : (plan as PlanData).features;

    final hasDynamic = plans.any((p) => p is Plan);
    final engine = QuoteEngine();
    final exampleClaim = 5000.0;

    final selectedPlan = plans[selectedIndex];

    int reimburseOf(dynamic plan) => planReimburse(plan);
    int deductibleOf(dynamic plan) => planDeductible(plan);
    int? limitOf(dynamic plan) {
      if (plan is Plan) {
        if (plan.isUnlimitedAnnualCoverage ||
            plan.maxAnnualCoverage.isInfinite) {
          return null;
        }
        return plan.maxAnnualCoverage.toInt();
      }
      return (plan as PlanData).annualLimit;
    }

    final reimburseBest = plans
        .map(reimburseOf)
        .reduce((a, b) => a > b ? a : b);
    final deductibleBest = plans
        .map(deductibleOf)
        .reduce((a, b) => a < b ? a : b);
    final limitValues = plans.map(limitOf).toList();
    final hasUnlimited = limitValues.any((v) => v == null);
    final limitBest = hasUnlimited
        ? null
        : limitValues.whereType<int>().fold<int>(0, (m, v) => v > m ? v : m);

    List<MapEntry<int, dynamic>> orderedColumns() {
      final entries = <MapEntry<int, dynamic>>[];
      for (var i = 0; i < plans.length; i++) {
        entries.add(MapEntry(i, plans[i]));
      }
      if (!pinSelected) return entries;
      final selected = entries.removeAt(selectedIndex);
      entries.insert(0, selected);
      return entries;
    }

    final columns = orderedColumns();

    Widget headerCell(dynamic plan, int originalIndex) {
      final accent = _tierColor(plan);
      final selected = originalIndex == selectedIndex;
      final tagline = _tierTagline(plan);
      const selectionAccent = ClovaraColors.clover;

      return SizedBox(
        width: colWidth,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? selectionAccent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? selectionAccent : AppColors.border,
                      ),
                    ),
                    child: Icon(_tierIcon(plan), color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      planName(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                ],
              ),
              if (tagline != null) ...[
                const SizedBox(height: 8),
                Text(
                  tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else
                const SizedBox(height: 10),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '\$${planMonthly(plan).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepGreen,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '/mo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? selectionAccent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: selected ? selectionAccent : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget valueCell(
      dynamic plan,
      String value, {
      Color? emphasis,
      bool highlight = false,
      String? delta,
    }) {
      final accent = _tierColor(plan);
      return SizedBox(
        width: colWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: highlight ? AppColors.surface2 : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: emphasis ?? accent,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 3),
                Text(
                  delta,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget rowLabel(String title, {String? subtitle}) {
      return SizedBox(
        width: labelWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: ClovaraColors.forest,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget divider() => Container(height: 1, color: Colors.grey.shade200);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Compare plans',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  color: ClovaraColors.forest,
                ),
              ),
            ),
            if (isMobile)
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Quickly see price and coverage differences across tiers.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (recommendedIndex != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ClovaraColors.clover),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: ClovaraColors.clover,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended: ${planName(plans[recommendedIndex])}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recommendationReason(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ClovaraColors.forest,
                  ),
                ),
              ),
              ToggleButtons(
                isSelected: [pinSelected, !pinSelected],
                onPressed: (i) => onTogglePinSelected(i == 0),
                borderRadius: BorderRadius.circular(12),
                selectedColor: ClovaraColors.forest,
                color: Colors.grey.shade700,
                fillColor: ClovaraColors.mist,
                constraints: BoxConstraints(
                  minHeight: 38,
                  minWidth: isMobile ? 130 : 160,
                ),
                children: const [
                  Text(
                    'Compare to selected',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  Text(
                    'Compare all',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: labelWidth),
                    ...List.generate(columns.length, (i) {
                      final entry = columns[i];
                      final originalIndex = entry.key;
                      final plan = entry.value;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelectIndex(originalIndex),
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == columns.length - 1 ? 0 : 12,
                          ),
                          child: headerCell(plan, originalIndex),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowLabel(
                      'Reimbursement',
                      subtitle: 'Higher % → you pay less',
                    ),
                    ...List.generate(columns.length, (i) {
                      final plan = columns[i].value;
                      final v = reimburseOf(plan);
                      final selectedV = reimburseOf(selectedPlan);
                      final d = v - selectedV;
                      final delta = pinSelected && plan != selectedPlan
                          ? '${d >= 0 ? '+' : ''}$d% vs selected'
                          : null;
                      return valueCell(
                        plan,
                        '$v%',
                        highlight: v == reimburseBest,
                        delta: delta,
                      );
                    }),
                  ],
                ),
                divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowLabel(
                      'Annual deductible',
                      subtitle: 'Higher → lower premium',
                    ),
                    ...List.generate(columns.length, (i) {
                      final plan = columns[i].value;
                      final v = deductibleOf(plan);
                      final selectedV = deductibleOf(selectedPlan);
                      final d = v - selectedV;
                      final delta = pinSelected && plan != selectedPlan
                          ? '${d >= 0 ? '+' : ''}\$${d.abs()} vs selected'
                          : null;
                      return valueCell(
                        plan,
                        '\$$v',
                        highlight: v == deductibleBest,
                        delta: delta,
                      );
                    }),
                  ],
                ),
                divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowLabel(
                      'Annual limit',
                      subtitle: 'More coverage → higher premium',
                    ),
                    ...List.generate(columns.length, (i) {
                      final plan = columns[i].value;
                      final v = limitOf(plan);
                      final selectedV = limitOf(selectedPlan);
                      final highlight = v == null
                          ? hasUnlimited
                          : (limitBest != null && v == limitBest);
                      String? delta;
                      if (pinSelected && plan != selectedPlan) {
                        if (v == null && selectedV != null) {
                          delta = '+ Unlimited vs selected';
                        } else if (v != null && selectedV == null) {
                          delta = '- Limited vs selected';
                        } else if (v != null && selectedV != null) {
                          final d = v - selectedV;
                          delta =
                              '${d >= 0 ? '+' : ''}\$${(d.abs() / 1000).toStringAsFixed(0)}k vs selected';
                        }
                      }
                      return valueCell(
                        plan,
                        planLimit(plan),
                        highlight: highlight,
                        delta: delta,
                      );
                    }),
                  ],
                ),
                if (hasDynamic) ...[
                  divider(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      rowLabel(
                        'Example claim',
                        subtitle:
                            'Estimated out-of-pocket for \$${exampleClaim.toStringAsFixed(0)}',
                      ),
                      ...List.generate(columns.length, (i) {
                        final p = columns[i].value;
                        if (p is! Plan)
                          return valueCell(
                            p,
                            '—',
                            emphasis: Colors.grey.shade700,
                          );
                        final oop = engine.calculateOutOfPocket(
                          plan: p,
                          claimAmount: exampleClaim,
                        );
                        final selectedOop = selectedPlan is Plan
                            ? engine.calculateOutOfPocket(
                                plan: selectedPlan,
                                claimAmount: exampleClaim,
                              )
                            : null;
                        final d = selectedOop == null
                            ? null
                            : (oop - selectedOop);
                        final delta =
                            (pinSelected && d != null && p != selectedPlan)
                            ? '${d >= 0 ? '+' : ''}\$${d.abs().toStringAsFixed(0)} vs selected'
                            : null;
                        return valueCell(
                          p,
                          '\$${oop.toStringAsFixed(0)}',
                          emphasis: Colors.grey.shade900,
                          delta: delta,
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Highlights',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ClovaraColors.forest,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(plans.length, (i) {
          final plan = plans[i];
          final accent = _tierColor(plan);
          final isSelected = i == _selectedPlanIndex;
          final feats = planFeatures(plan);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? ClovaraColors.clover : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? ClovaraColors.clover
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(_tierIcon(plan), color: accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        planName(plan),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                    Text(
                      '\$${planMonthly(plan).toStringAsFixed(0)}/mo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...feats
                    .take(isMobile ? 6 : 8)
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 18, color: accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (feats.length > (isMobile ? 6 : 8))
                  Text(
                    '+ ${feats.length - (isMobile ? 6 : 8)} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  int? _resolveAgeYearsFromRoute() {
    final args = _routeArguments;
    if (args == null) return null;

    // Common shapes: {pet: Pet}, {petData: Map}, {ageYears: int}, etc.
    dynamic v = args['ageYears'] ?? args['petAgeYears'] ?? args['petAge'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());

    final pet =
        args['pet'] ??
        args['petData'] ??
        args['pet_profile'] ??
        args['profile'];
    if (pet is Map) {
      final raw =
          pet['ageYears'] ??
          pet['age_years'] ??
          pet['age'] ??
          pet['petAgeYears'];
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
    } else {
      // Best-effort reflective reads; avoid hard dependency on Pet model.
      try {
        final dynamic years = (pet as dynamic).ageYears;
        if (years is num) return years.toInt();
      } catch (_) {}
      try {
        final dynamic years = (pet as dynamic).ageInYears;
        if (years is num) return years.toInt();
      } catch (_) {}
    }

    return null;
  }

  Widget _buildCustomizationPanel(Plan plan) {
    // Only for dynamic Plan (not static fallback)
    final selectedAddOns = plan.selectedAddOns
        .map(
          (s) => AddOnType.values.firstWhere(
            (e) => e.name == s || e.toString() == s,
            orElse: () => AddOnType.examFees,
          ),
        )
        .toSet();

    int? currentAnnualLimit;
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) {
      currentAnnualLimit = null;
    } else {
      currentAnnualLimit = plan.maxAnnualCoverage.toInt();
    }

    final ageYears = _resolveAgeYearsFromRoute();

    final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedAnnualLimits = ProductCatalog.annualLimitOptionsFor(
      riskBand: plan.riskBand,
      ageYears: ageYears,
    );

    int currentReimbursement = plan.reimbursementPercent;
    if (!allowedReimbursements.contains(currentReimbursement)) {
      currentReimbursement = allowedReimbursements.isEmpty
          ? 70
          : allowedReimbursements.last;
    }

    int currentDeductible = plan.annualDeductible.toInt();
    if (!allowedDeductibles.contains(currentDeductible)) {
      currentDeductible = allowedDeductibles.isEmpty
          ? 500
          : allowedDeductibles.first;
    }

    // If current selection is no longer allowed, coerce to max finite.
    if (!allowedAnnualLimits.contains(currentAnnualLimit)) {
      final coerced = allowedAnnualLimits.whereType<int>().isEmpty
          ? 10000
          : (allowedAnnualLimits.whereType<int>().toList()..sort()).last;
      currentAnnualLimit = coerced;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    Future<Plan> rebuild({
      int? reimbursementPercent,
      int? annualDeductible,
      int? annualLimit,
      bool annualLimitProvided = false,
      Set<AddOnType>? addOns,
    }) async {
      final nextReimb = reimbursementPercent ?? currentReimbursement;
      final nextDed = annualDeductible ?? currentDeductible;
      final nextLimit = annualLimitProvided ? annualLimit : currentAnnualLimit;
      final nextAddOns = (addOns ?? selectedAddOns).toList();

      // Prefer server-side pricing so admin versions take effect immediately.
      try {
        final owner = _routeArguments?['owner'] as Owner?;
        if (owner != null) {
          final svc = PricingQuoteService();
          final priced = await svc.priceSku(
            riskBand: plan.riskBand.name,
            zipCode: owner.address.zipCode,
            state: owner.address.state,
            numberOfPets: plan.numberOfPets,
            tier: plan.type.name,
            reimbursementPercent: nextReimb,
            annualDeductible: nextDed,
            annualLimit: nextLimit,
            addOns: nextAddOns.map((e) => e.name).toList(growable: false),
          );
          if (priced != null) return priced;
        }
      } catch (_) {
        // Fall back to local pricing to keep UX unblocked.
      }

      final engine = QuoteEngine();
      return engine.buildPlan(
        tier: plan.type,
        basePremium: plan.pricingBasePremium,
        riskBand: plan.riskBand,
        numberOfPets: plan.numberOfPets,
        discount: plan.multiPetDiscount,
        regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
        regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
        ageYears: ageYears,
        reimbursementPercent: nextReimb,
        annualDeductible: nextDed,
        annualLimit: nextLimit,
        addOns: nextAddOns,
      );
    }

    Future<void> pickReimbursement() async {
      final picked = await _pickOptionSheet<int>(
        title: 'Reimbursement',
        options: allowedReimbursements,
        selected: currentReimbursement,
        labelFor: (v) => '$v%',
      );
      if (picked == null) return;
      _updateSelectedPlan(await rebuild(reimbursementPercent: picked));
    }

    Future<void> pickDeductible() async {
      final picked = await _pickOptionSheet<int>(
        title: 'Annual deductible',
        options: allowedDeductibles,
        selected: currentDeductible,
        labelFor: (v) => '\$$v',
      );
      if (picked == null) return;
      _updateSelectedPlan(await rebuild(annualDeductible: picked));
    }

    Future<void> pickAnnualLimit() async {
      final picked = await _pickOptionSheet<int?>(
        title: 'Annual limit',
        options: allowedAnnualLimits,
        selected: currentAnnualLimit,
        labelFor: (v) =>
            v == null ? 'Unlimited' : '\$${(v / 1000).toStringAsFixed(0)}k',
      );
      if (picked == null) return;
      _updateSelectedPlan(
        await rebuild(annualLimit: picked, annualLimitProvided: true),
      );
    }

    final visibleAddOns = AddOn.all.where((addon) {
      final availability = _availability;
      if (availability == null) return true;
      return ProductCatalogAvailabilityEngine.isAddOnEnabled(
        availability,
        addon.type.name,
      );
    }).toList();

    return Container(
      margin: EdgeInsets.fromLTRB(isWide ? 32 : 20, 12, isWide ? 32 : 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isWide,
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Customize coverage',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: ClovaraColors.forest,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniPill(
                  icon: Icons.percent,
                  text: '$currentReimbursement% reimbursement',
                ),
                _buildMiniPill(
                  icon: Icons.payments_outlined,
                  text: '\$$currentDeductible deductible',
                ),
                _buildMiniPill(
                  icon: Icons.shield_outlined,
                  text: currentAnnualLimit == null
                      ? 'Unlimited annual'
                      : '\$${(currentAnnualLimit / 1000).toStringAsFixed(0)}k annual',
                ),
              ],
            ),
          ),
          children: [
            if (_isLoadingAvailability)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading available products…',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cols = w >= 920 ? 3 : (w >= 560 ? 2 : 1);
                const gap = 12.0;
                final itemWidth = (w - gap * (cols - 1)) / cols;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildLeverCard(
                        icon: Icons.percent,
                        label: 'Reimbursement',
                        valueText: '$currentReimbursement%',
                        helperText: 'Higher reimbursement → higher premium',
                        onTap: pickReimbursement,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildLeverCard(
                        icon: Icons.payments_outlined,
                        label: 'Annual deductible',
                        valueText: '\$$currentDeductible',
                        helperText: 'Higher deductible → lower premium',
                        onTap: pickDeductible,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildLeverCard(
                        icon: Icons.shield_outlined,
                        label: 'Annual limit',
                        valueText: currentAnnualLimit == null
                            ? 'Unlimited'
                            : '\$${(currentAnnualLimit / 1000).toStringAsFixed(0)}k',
                        helperText: 'More coverage → higher premium',
                        onTap: pickAnnualLimit,
                      ),
                    ),
                  ],
                );
              },
            ),

            if (visibleAddOns.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Add-ons',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ClovaraColors.forest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cols = w >= 1050
                      ? 4
                      : (w >= 820 ? 3 : (w >= 520 ? 2 : 1));
                  return GridView.count(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: cols == 1 ? 4.2 : 2.9,
                    children: [
                      for (final addon in visibleAddOns)
                        _buildAddOnTile(
                          addon: addon,
                          selected: selectedAddOns.contains(addon.type),
                          onToggle: (nextSelected) async {
                            final next = Set<AddOnType>.from(selectedAddOns);
                            if (nextSelected) {
                              next.add(addon.type);
                            } else {
                              next.remove(addon.type);
                            }
                            _updateSelectedPlan(await rebuild(addOns: next));
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCustomizationSheet(Plan plan) {
    // Mirror the same computation as the in-page panel, but present it as a
    // persistent, draggable sheet on mobile so users can tweak coverage
    // without losing the price + CTA.
    final selectedAddOns = plan.selectedAddOns
        .map(
          (s) => AddOnType.values.firstWhere(
            (e) => e.name == s || e.toString() == s,
            orElse: () => AddOnType.examFees,
          ),
        )
        .toSet();

    int? currentAnnualLimit;
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) {
      currentAnnualLimit = null;
    } else {
      currentAnnualLimit = plan.maxAnnualCoverage.toInt();
    }

    final ageYears = _resolveAgeYearsFromRoute();

    final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedAnnualLimits = ProductCatalog.annualLimitOptionsFor(
      riskBand: plan.riskBand,
      ageYears: ageYears,
    );

    int currentReimbursement = plan.reimbursementPercent;
    if (!allowedReimbursements.contains(currentReimbursement)) {
      currentReimbursement = allowedReimbursements.isEmpty
          ? 70
          : allowedReimbursements.last;
    }

    int currentDeductible = plan.annualDeductible.toInt();
    if (!allowedDeductibles.contains(currentDeductible)) {
      currentDeductible = allowedDeductibles.isEmpty
          ? 500
          : allowedDeductibles.first;
    }

    // If current selection is no longer allowed, coerce to max finite.
    if (!allowedAnnualLimits.contains(currentAnnualLimit)) {
      final coerced = allowedAnnualLimits.whereType<int>().isEmpty
          ? 10000
          : (allowedAnnualLimits.whereType<int>().toList()..sort()).last;
      currentAnnualLimit = coerced;
    }

    Future<Plan> rebuild({
      int? reimbursementPercent,
      int? annualDeductible,
      int? annualLimit,
      bool annualLimitProvided = false,
      Set<AddOnType>? addOns,
    }) async {
      final nextReimb = reimbursementPercent ?? currentReimbursement;
      final nextDed = annualDeductible ?? currentDeductible;
      final nextLimit = annualLimitProvided ? annualLimit : currentAnnualLimit;
      final nextAddOns = (addOns ?? selectedAddOns).toList();

      try {
        final owner = _routeArguments?['owner'] as Owner?;
        if (owner != null) {
          final svc = PricingQuoteService();
          final priced = await svc.priceSku(
            riskBand: plan.riskBand.name,
            zipCode: owner.address.zipCode,
            state: owner.address.state,
            numberOfPets: plan.numberOfPets,
            tier: plan.type.name,
            reimbursementPercent: nextReimb,
            annualDeductible: nextDed,
            annualLimit: nextLimit,
            addOns: nextAddOns.map((e) => e.name).toList(growable: false),
          );
          if (priced != null) return priced;
        }
      } catch (_) {
        // Ignore.
      }

      final engine = QuoteEngine();
      return engine.buildPlan(
        tier: plan.type,
        basePremium: plan.pricingBasePremium,
        riskBand: plan.riskBand,
        numberOfPets: plan.numberOfPets,
        discount: plan.multiPetDiscount,
        regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
        regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
        ageYears: ageYears,
        reimbursementPercent: nextReimb,
        annualDeductible: nextDed,
        annualLimit: nextLimit,
        addOns: nextAddOns,
      );
    }

    Future<void> pickReimbursement() async {
      final picked = await _pickOptionSheet<int>(
        title: 'Reimbursement',
        options: allowedReimbursements,
        selected: currentReimbursement,
        labelFor: (v) => '$v%',
      );
      if (picked == null) return;
      _updateSelectedPlan(await rebuild(reimbursementPercent: picked));
    }

    Future<void> pickDeductible() async {
      final picked = await _pickOptionSheet<int>(
        title: 'Annual deductible',
        options: allowedDeductibles,
        selected: currentDeductible,
        labelFor: (v) => '\$$v',
      );
      if (picked == null) return;
      _updateSelectedPlan(await rebuild(annualDeductible: picked));
    }

    Future<void> pickAnnualLimit() async {
      final picked = await _pickOptionSheet<int?>(
        title: 'Annual limit',
        options: allowedAnnualLimits,
        selected: currentAnnualLimit,
        labelFor: (v) =>
            v == null ? 'Unlimited' : '\$${(v / 1000).toStringAsFixed(0)}k',
      );
      if (picked == null) return;
      _updateSelectedPlan(
        await rebuild(annualLimit: picked, annualLimitProvided: true),
      );
    }

    final visibleAddOns = AddOn.all.where((addon) {
      final availability = _availability;
      if (availability == null) return true;
      return ProductCatalogAvailabilityEngine.isAddOnEnabled(
        availability,
        addon.type.name,
      );
    }).toList();

    final availableHeight = MediaQuery.of(context).size.height;
    // Ensure the collapsed sheet has enough room for its fixed header content,
    // even when the parent height is reduced by tabs + CTA.
    const minCollapsedPixels = 128.0;
    final minChildSize = (minCollapsedPixels / availableHeight)
        .clamp(0.20, 0.34)
        .toDouble();

    return DraggableScrollableSheet(
      controller: _customizerController,
      minChildSize: minChildSize,
      initialChildSize: minChildSize,
      maxChildSize: 0.80,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      // Make the header feel like a primary action.
                      _customizerController.animateTo(
                        0.58,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ClovaraColors.clover),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            size: 18,
                            color: ClovaraColors.forest,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customize coverage',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: ClovaraColors.forest,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to adjust reimbursement, deductible, and limit',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: ClovaraColors.clover,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Customize',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.grey.shade800,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$currentReimbursement% reimbursement • \$$currentDeductible deductible • '
                        '${currentAnnualLimit == null ? 'Unlimited' : '\$${(currentAnnualLimit / 1000).toStringAsFixed(0)}k'} annual',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    if (_isLoadingAvailability)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading available products…',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final cols = w >= 560 ? 2 : 1;
                        const gap = 12.0;
                        final itemWidth = (w - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _buildLeverCard(
                                icon: Icons.percent,
                                label: 'Reimbursement',
                                valueText: '$currentReimbursement%',
                                helperText:
                                    'Higher reimbursement → higher premium',
                                onTap: pickReimbursement,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildLeverCard(
                                icon: Icons.payments_outlined,
                                label: 'Annual deductible',
                                valueText: '\$$currentDeductible',
                                helperText: 'Higher deductible → lower premium',
                                onTap: pickDeductible,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildLeverCard(
                                icon: Icons.shield_outlined,
                                label: 'Annual limit',
                                valueText: currentAnnualLimit == null
                                    ? 'Unlimited'
                                    : '\$${(currentAnnualLimit / 1000).toStringAsFixed(0)}k',
                                helperText: 'More coverage → higher premium',
                                onTap: pickAnnualLimit,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (visibleAddOns.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Add-ons',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ClovaraColors.forest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cols = w >= 520 ? 2 : 1;
                          return GridView.count(
                            crossAxisCount: cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: cols == 1 ? 4.2 : 2.9,
                            children: [
                              for (final addon in visibleAddOns)
                                _buildAddOnTile(
                                  addon: addon,
                                  selected: selectedAddOns.contains(addon.type),
                                  onToggle: (nextSelected) async {
                                    final next = Set<AddOnType>.from(
                                      selectedAddOns,
                                    );
                                    if (nextSelected) {
                                      next.add(addon.type);
                                    } else {
                                      next.remove(addon.type);
                                    }
                                    _updateSelectedPlan(
                                      await rebuild(addOns: next),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeverCard({
    required IconData icon,
    required String label,
    required String valueText,
    required String helperText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ClovaraColors.mist,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ClovaraColors.forest, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ClovaraColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helperText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOnTile({
    required AddOn addon,
    required bool selected,
    required void Function(bool nextSelected) onToggle,
  }) {
    final borderColor = selected ? ClovaraColors.clover : AppColors.border;
    const bg = Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onToggle(!selected),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected ? ClovaraColors.clover : AppColors.border,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check : Icons.add,
                  size: 16,
                  color: selected ? ClovaraColors.clover : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      addon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      addon.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<T?> _pickOptionSheet<T>({
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T v) labelFor,
  }) async {
    final width = MediaQuery.of(context).size.width;
    final useDialog = width >= 700;

    if (useDialog) {
      return showDialog<T>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final opt in options)
                      RadioListTile<T>(
                        value: opt,
                        groupValue: selected,
                        title: Text(labelFor(opt)),
                        onChanged: (v) => Navigator.pop(context, v),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ClovaraColors.forest,
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map(
                  (opt) => RadioListTile<T>(
                    value: opt,
                    groupValue: selected,
                    title: Text(
                      labelFor(opt),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onChanged: (v) => Navigator.pop(context, v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPricingBreakdownSection(Plan plan, Color color) {
    final breakdown = plan.pricingBreakdown;
    if (breakdown == null) return const SizedBox.shrink();
    final versionLabel = breakdown.pricingVersion.startsWith('v')
        ? breakdown.pricingVersion
        : 'v${breakdown.pricingVersion}';

    String fmtMoney(double v) => '\$${v.toStringAsFixed(2)}';

    final addOns = breakdown.addOnMonthlyLoads.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            'Pricing breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ClovaraColors.forest,
            ),
          ),
          subtitle: Text(
            '$versionLabel • ${breakdown.effectiveDateIso}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            _buildBreakdownRow(
              'Base risk rate',
              fmtMoney(breakdown.baseRiskRate),
            ),
            _buildBreakdownRow(
              'Risk band',
              '${breakdown.riskBand.name} (×${breakdown.riskBandMultiplier.toStringAsFixed(2)})',
            ),
            _buildBreakdownRow(
              'Region',
              '${breakdown.regionalKey} (×${breakdown.regionalMultiplier.toStringAsFixed(2)})',
            ),
            _buildBreakdownRow(
              'Multi-pet discount',
              '${(breakdown.multiPetDiscount * 100).toStringAsFixed(0)}%',
            ),
            _buildBreakdownRow(
              'Pricing base premium',
              fmtMoney(breakdown.pricingBasePremium),
            ),
            _buildBreakdownRow(
              'Reimbursement',
              '${breakdown.reimbursementPercent}% (×${breakdown.reimbursementFactor.toStringAsFixed(2)})',
            ),
            _buildBreakdownRow(
              'Deductible',
              '\$${breakdown.annualDeductible} (×${breakdown.deductibleFactor.toStringAsFixed(2)})',
            ),
            _buildBreakdownRow(
              'Annual limit',
              '${breakdown.annualLimit == null ? 'Unlimited' : '\$${breakdown.annualLimit}'} (×${breakdown.annualLimitFactor.toStringAsFixed(2)})',
            ),
            const SizedBox(height: 8),
            _buildBreakdownRow(
              'Premium before add-ons',
              fmtMoney(breakdown.premiumBeforeAddOns),
            ),
            if (addOns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Add-ons',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              ...addOns.map(
                (e) => _buildBreakdownRow(e.key, '+ ${fmtMoney(e.value)}'),
              ),
            ],
            const SizedBox(height: 8),
            _buildBreakdownRow(
              'Add-on total',
              '+ ${fmtMoney(breakdown.addOnTotal)}',
            ),
            if (breakdown.minPremiumApplied)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Minimum premium applied',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            _buildBreakdownRow(
              'Final monthly premium',
              fmtMoney(breakdown.finalMonthlyPremium),
              valueStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style:
                valueStyle ??
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  int _getRecommendedPlanIndex(RiskScore riskScore, int planCount) {
    if (planCount <= 0) return 0;
    final raw = switch (riskScore.riskLevel) {
      RiskLevel.low => 0,
      RiskLevel.medium => 1,
      RiskLevel.high => 2,
      RiskLevel.veryHigh => 2,
    };
    return raw.clamp(0, planCount - 1);
  }

  List<dynamic> get _plans {
    final source = _dynamicPlans != null && _dynamicPlans!.isNotEmpty
        ? _dynamicPlans!
        : _staticPlans;

    return source.where((p) {
      if (p is Plan) return p.type != PlanType.unlimited;
      if (p is PlanData) return p.name.toLowerCase() != 'unlimited';
      return true;
    }).toList();
  }

  final List<PlanData> _staticPlans = [
    PlanData(
      name: 'Basic',
      monthlyPrice: 29.99,
      annualDeductible: 500,
      reimbursement: 70,
      annualLimit: 10000,
      features: [
        'Accidents & Illnesses',
        '70% Reimbursement',
        '\$10,000 Annual Limit',
        '\$500 Deductible',
        '24/7 Vet Helpline',
      ],
      color: AppColors.textMuted,
    ),
    PlanData(
      name: 'Standard',
      monthlyPrice: 49.99,
      annualDeductible: 250,
      reimbursement: 80,
      annualLimit: 10000,
      features: [
        'Accidents & Illnesses',
        '80% Reimbursement',
        '\$10,000 Annual Limit',
        '\$250 Deductible',
        'Wellness Add-on Available',
        '24/7 Vet Helpline',
        'Prescription Coverage',
      ],
      color: ClovaraColors.clover,
      isPopular: true,
    ),
    PlanData(
      name: 'Premium',
      monthlyPrice: 79.99,
      annualDeductible: 250,
      reimbursement: 90,
      annualLimit: 20000,
      features: [
        'Accidents & Illnesses',
        '90% Reimbursement',
        '\$20,000 Annual Limit',
        '\$250 Deductible',
        'Wellness Coverage Included',
        'Dental Coverage',
        '24/7 Vet Helpline',
        'Prescription Coverage',
        'Alternative Therapies',
      ],
      color: AppColors.deepGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 980;

    if (_isLoadingPlans) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(ClovaraColors.clover),
              ),
              const SizedBox(height: 20),
              Text(
                'Creating your plans...',
                style: TextStyle(
                  fontSize: 16,
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_pricingAllowed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildPricingBlocked(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildModernAppBar(context),
      body: Container(
        decoration: const BoxDecoration(color: AppColors.background),
        child: isMobile ? _buildMobileV2() : _buildDesktopV2(),
      ),
      bottomNavigationBar: _buildStickyCheckoutBar(),
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context) {
    final petName = _tryGetPetNameFromRoute();
    final subtitle = petName == null
        ? 'Pick coverage that fits your budget'
        : 'For $petName — pick coverage that fits your budget';

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: AppColors.deepGreen),
        tooltip: 'Back',
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your plan',
            style: TextStyle(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Back to website home?'),
                content: const Text(
                  'If you leave now, your quote and plan selection may be lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
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
          style: TextButton.styleFrom(foregroundColor: AppColors.deepGreen),
        ),
        _buildAccountIcon(context),
        const SizedBox(width: 8),
      ],
    );
  }

  String? _tryGetPetNameFromRoute() {
    final args = _routeArguments;
    if (args == null) return null;
    final pet = args['pet'] ?? args['petData'];
    if (pet is Map) {
      final name = pet['name']?.toString().trim();
      return (name == null || name.isEmpty) ? null : name;
    }
    try {
      final dynamic name = (pet as dynamic).name;
      final s = name?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    } catch (_) {
      return null;
    }
  }

  void _continueToCheckout() {
    context.push(
      '/checkout',
      extra: {
        'pet': _routeArguments?['petData'] ?? _routeArguments?['pet'] ?? {},
        'selectedPlan': _plans[_selectedPlanIndex],
        'riskScore': _routeArguments?['riskScore'],
        'underwritingCaseId': _routeArguments?['underwritingCaseId'],
        'exclusions':
            _routeArguments?['exclusions'] ??
            _routeArguments?['excludedConditions'],
        'underwritingSnapshot': _routeArguments?['underwritingSnapshot'],
      },
    );
  }

  AddOnType? _tryParseAddOnType(Object? value) {
    if (value == null) return null;
    if (value is AddOnType) return value;
    final s = value.toString();
    for (final e in AddOnType.values) {
      if (e.name == s || e.toString() == s) return e;
    }
    return null;
  }

  Set<AddOnType> _selectedAddOnsOf(Plan plan) {
    return plan.selectedAddOns
        .map(_tryParseAddOnType)
        .whereType<AddOnType>()
        .toSet();
  }

  List<AddOn> _visibleAddOns() {
    return AddOn.all
        .where((addon) {
          final availability = _availability;
          if (availability == null) return true;
          return ProductCatalogAvailabilityEngine.isAddOnEnabled(
            availability,
            addon.type.name,
          );
        })
        .toList(growable: false);
  }

  int _addOnPriority(AddOn a) {
    final t = a.type;
    if (t == AddOnType.wellnessPremium) return 0;
    if (t == AddOnType.wellnessLite) return 1;
    if (t == AddOnType.examFees) return 2;
    if (t == AddOnType.dentalPlus) return 3;
    if (t == AddOnType.rehab) return 4;
    if (t == AddOnType.behavioral) return 5;
    if (t == AddOnType.prescriptionFood) return 6;
    return 10;
  }

  Future<Plan> _repricePlanWithAddOns(Plan base, Set<AddOnType> addOns) async {
    final ageYears = _resolveAgeYearsFromRoute();

    int? annualLimit;
    if (base.isUnlimitedAnnualCoverage || base.maxAnnualCoverage.isInfinite) {
      annualLimit = null;
    } else {
      annualLimit = base.maxAnnualCoverage.toInt();
    }

    try {
      final owner = _routeArguments?['owner'] as Owner?;
      if (owner != null) {
        final svc = PricingQuoteService();
        final priced = await svc.priceSku(
          riskBand: base.riskBand.name,
          zipCode: owner.address.zipCode,
          state: owner.address.state,
          numberOfPets: base.numberOfPets,
          tier: base.type.name,
          reimbursementPercent: base.reimbursementPercent,
          annualDeductible: base.annualDeductible.toInt(),
          annualLimit: annualLimit,
          addOns: addOns.map((e) => e.name).toList(growable: false),
        );
        if (priced != null) return priced;
      }
    } catch (_) {
      // Fall back to local pricing.
    }

    final engine = QuoteEngine();
    return engine.buildPlan(
      tier: base.type,
      basePremium: base.pricingBasePremium,
      riskBand: base.riskBand,
      numberOfPets: base.numberOfPets,
      discount: base.multiPetDiscount,
      regionalMultiplier: base.pricingBreakdown?.regionalMultiplier ?? 1.0,
      regionalKey: base.pricingBreakdown?.regionalKey ?? 'DEFAULT',
      ageYears: ageYears,
      reimbursementPercent: base.reimbursementPercent,
      annualDeductible: base.annualDeductible.toInt(),
      annualLimit: annualLimit,
      addOns: addOns.toList(growable: false),
    );
  }

  Widget _buildAddOnUpsellCard({
    required AddOn addon,
    required bool selected,
    required String? priceLabel,
    required VoidCallback onTap,
  }) {
    const accent = ClovaraColors.clover;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.br20,
        child: CheckoutCard(
          selected: selected,
          accent: accent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? accent : AppColors.border,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  color: selected ? accent : AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            addon.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (priceLabel != null)
                          Text(
                            priceLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addon.description,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOnsUpsellSection(Plan plan, {required bool isMobile}) {
    final all = _visibleAddOns();
    if (all.isEmpty) return const SizedBox.shrink();

    final selected = _selectedAddOnsOf(plan);
    final addOnLoads =
        plan.pricingBreakdown?.addOnMonthlyLoads ?? const <String, double>{};

    final sorted = List<AddOn>.from(all)
      ..sort((a, b) => _addOnPriority(a).compareTo(_addOnPriority(b)));
    final top = sorted.take(3).toList(growable: false);
    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Most pet parents add one',
          style: TextStyle(
            fontSize: isMobile ? 15 : 14,
            fontWeight: FontWeight.w900,
            color: ClovaraColors.forest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional add-ons you can turn on in seconds.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        if (isMobile) ...[
          for (final addon in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAddOnUpsellCard(
                addon: addon,
                selected: selected.contains(addon.type),
                priceLabel: addOnLoads[addon.type.name] == null
                    ? null
                    : '+ \$${addOnLoads[addon.type.name]!.toStringAsFixed(2)}/mo',
                onTap: () async {
                  final next = Set<AddOnType>.from(selected);
                  if (next.contains(addon.type)) {
                    next.remove(addon.type);
                  } else {
                    next.add(addon.type);
                  }
                  _updateSelectedPlan(await _repricePlanWithAddOns(plan, next));
                },
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _openCoverageCustomizerBottomSheet(plan),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClovaraColors.forest,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text(
                'See all add-ons',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ] else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final addon in top)
                SizedBox(
                  width: 320,
                  child: _buildAddOnUpsellCard(
                    addon: addon,
                    selected: selected.contains(addon.type),
                    priceLabel: addOnLoads[addon.type.name] == null
                        ? null
                        : '+ \$${addOnLoads[addon.type.name]!.toStringAsFixed(2)}/mo',
                    onTap: () async {
                      final next = Set<AddOnType>.from(selected);
                      if (next.contains(addon.type)) {
                        next.remove(addon.type);
                      } else {
                        next.add(addon.type);
                      }
                      _updateSelectedPlan(
                        await _repricePlanWithAddOns(plan, next),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStickyCheckoutBar() {
    final plan = _plans[_selectedPlanIndex];
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ClovaraColors.forest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price.toStringAsFixed(0)}/mo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _continueToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClovaraColors.clover,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileV2() {
    final selected = _plans[_selectedPlanIndex];
    _syncMobilePlanController();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _buildProgressHero(),
          ),
        ),
        SliverToBoxAdapter(child: _buildExclusionsCallout()),
        SliverToBoxAdapter(child: _buildMobilePlanCarousel()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildSelectedPlanOverview(selected, isCompact: true),
          ),
        ),
        if (selected is Plan)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildAddOnsUpsellSection(selected, isMobile: true),
            ),
          ),
        if (selected is Plan)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildCoverageCustomizerCard(selected, isMobile: true),
            ),
          ),
        if (selected is Plan)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildExampleBillsAccordion(selected),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: _buildIncludedCard(selected),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(
              Icons.shield_moon_outlined,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 2 of 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose coverage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ClovaraColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Swipe plans, then customize your deductible and reimbursement.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _syncMobilePlanController() {
    if (!_mobilePlanController.hasClients) return;
    final current =
        (_mobilePlanController.page ?? _mobilePlanController.initialPage)
            .round();
    if (current == _selectedPlanIndex) return;
    _mobilePlanController.jumpToPage(_selectedPlanIndex);
  }

  Widget _buildMobilePlanCarousel() {
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final planCount = _plans.length;
    final screenH = MediaQuery.sizeOf(context).height;
    // Slightly taller to avoid overflows on short web/mobile viewports.
    final carouselHeight = (screenH * 0.36).clamp(280.0, 340.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Text(
                'Plans',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ClovaraColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                'Swipe',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.swipe, size: 16, color: Colors.grey.shade600),
            ],
          ),
        ),
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _mobilePlanController,
            itemCount: _plans.length,
            onPageChanged: (i) => _setSelectedPlanIndex(i),
            itemBuilder: (context, index) {
              final plan = _plans[index];
              final recommended =
                  riskScore != null &&
                  index == _getRecommendedPlanIndex(riskScore, planCount);
              final selected = index == _selectedPlanIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildPlanPickerCard(
                  plan: plan,
                  index: index,
                  selected: selected,
                  recommended: recommended,
                  onTap: () => setState(() => _selectedPlanIndex = index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _plans.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _selectedPlanIndex ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _selectedPlanIndex
                    ? ClovaraColors.clover
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _openComparePlans(isMobile: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClovaraColors.forest,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text(
                'Compare plans',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildDesktopV2() {
    final selected = _plans[_selectedPlanIndex];
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final accent = _tierColor(selected);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Plans',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ClovaraColors.forest,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _openComparePlans(isMobile: false),
                          icon: const Icon(
                            Icons.table_chart_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Compare',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: ClovaraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a tier, then personalize coverage and add-ons.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ...List.generate(_plans.length, (index) {
                                    final plan = _plans[index];
                                    final recommended =
                                        riskScore != null &&
                                        index ==
                                            _getRecommendedPlanIndex(
                                              riskScore,
                                              _plans.length,
                                            );
                                    final selected =
                                        index == _selectedPlanIndex;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: index == _plans.length - 1
                                            ? 0
                                            : 12,
                                      ),
                                      child: _buildPlanPickerCard(
                                        plan: plan,
                                        index: index,
                                        selected: selected,
                                        recommended: recommended,
                                        dense: true,
                                        onTap: () =>
                                            _setSelectedPlanIndex(index),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildExclusionsCallout(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: AppShadows.soft,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          icon: Icons.shield_outlined,
                          title: 'Coverage summary',
                          subtitle:
                              'Your price and core coverage levers at a glance.',
                          accent: accent,
                        ),
                        const SizedBox(height: 10),
                        _buildSelectedPlanOverview(selected),
                        const SizedBox(height: 16),
                        if (selected is Plan) ...[
                          _buildSectionLabel(
                            icon: Icons.auto_awesome,
                            title: 'Upgrade your plan',
                            subtitle:
                                'Add extras and tune your deductible and reimbursement.',
                            accent: accent,
                          ),
                          const SizedBox(height: 10),
                          _buildCoverageCustomizerCard(
                            selected,
                            isMobile: false,
                          ),
                          const SizedBox(height: 16),
                          _buildAddOnsUpsellSection(selected, isMobile: false),
                          const SizedBox(height: 16),
                        ],
                        _buildSectionLabel(
                          icon: Icons.check_circle_outline,
                          title: 'What\'s included',
                          subtitle:
                              'Included benefits and coverage highlights.',
                          accent: accent,
                        ),
                        const SizedBox(height: 10),
                        _buildIncludedCard(selected),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: ClovaraColors.forest, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPickerCard({
    required dynamic plan,
    required int index,
    required bool selected,
    required bool recommended,
    required VoidCallback onTap,
    bool dense = false,
  }) {
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;
    final deductible = plan is Plan
        ? plan.annualDeductible.toInt()
        : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan
        ? (100 - plan.coPayPercentage).toInt()
        : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan
        ? _formatAnnualLimit(plan)
        : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';

    final accent = _tierColor(plan);
    const selectionAccent = ClovaraColors.clover;
    final bg = Colors.white;
    final border = selected ? selectionAccent : AppColors.border;
    final tagline = _tierTagline(plan);

    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final highlight1 = features.isNotEmpty
        ? features.first
        : 'Accidents & illnesses';
    final highlight2 = features.length >= 2
        ? features[1]
        : 'Fast claims + 24/7 support';

    // Mobile card: bigger typography, stronger hierarchy, more “premium” layout.
    if (!dense) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: selected ? 2 : 1),
              color: bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? selectionAccent : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        selected ? Icons.check_circle : _tierIcon(plan),
                        color: selected ? selectionAccent : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.deepGreen,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (tagline != null)
                            Text(
                              tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            const SizedBox(height: 18),
                        ],
                      ),
                    ),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ClovaraColors.clover,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Recommended',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepGreen,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '/mo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '$reimburse% back • $limitLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKeyMetricPill(
                        icon: Icons.payments_outlined,
                        label: 'Deductible',
                        value: '\$$deductible',
                        accent: accent,
                      ),
                      const SizedBox(width: 10),
                      _buildKeyMetricPill(
                        icon: Icons.percent,
                        label: 'Reimbursement',
                        value: '$reimburse%',
                        accent: accent,
                      ),
                      const SizedBox(width: 10),
                      _buildKeyMetricPill(
                        icon: Icons.shield_outlined,
                        label: 'Limit',
                        value: limitLabel,
                        accent: accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildFeatureLine(highlight1, accent),
                const SizedBox(height: 8),
                _buildFeatureLine(highlight2, accent),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(dense ? 14 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: selected ? 2 : 1),
            color: bg,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? selectionAccent : AppColors.border,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_circle : _tierIcon(plan),
                  color: selected ? selectionAccent : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: dense ? 15 : 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ClovaraColors.clover,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Recommended',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (tagline != null) ...[
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: dense ? 13 : 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else
                      const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(0)}/mo',
                          style: TextStyle(
                            fontSize: dense ? 16 : 16,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$reimburse% • $limitLabel • \$$deductible ded.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: dense ? 13 : 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureLine(String text, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 18, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPlanOverview(dynamic plan, {bool isCompact = false}) {
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;
    final deductible = plan is Plan
        ? plan.annualDeductible.toInt()
        : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan
        ? (100 - plan.coPayPercentage).toInt()
        : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan
        ? _formatAnnualLimit(plan)
        : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    final accent = _tierColor(plan);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_tierIcon(plan), size: 16, color: ClovaraColors.clover),
                const SizedBox(width: 8),
                Text(
                  'Selected plan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: isCompact ? 16 : 20,
              fontWeight: FontWeight.w900,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: isCompact ? 34 : 46,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '/month',
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const Spacer(),
              if (plan is Plan)
                Text(
                  'Annual: \$${plan.annualPremium.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildKeyMetricChip(
                icon: Icons.percent,
                label: 'Reimbursement',
                value: '$reimburse%',
                accent: accent,
              ),
              _buildKeyMetricChip(
                icon: Icons.shield_outlined,
                label: 'Annual limit',
                value: limitLabel,
                accent: accent,
              ),
              _buildKeyMetricChip(
                icon: Icons.payments_outlined,
                label: 'Deductible',
                value: '\$$deductible',
                accent: accent,
              ),
            ],
          ),
          if (plan is Plan && !isCompact) ...[
            const SizedBox(height: 14),
            _buildExampleBills(plan),
          ],
        ],
      ),
    );
  }

  Widget _buildExampleBillsAccordion(Plan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          collapsedIconColor: AppColors.textMuted,
          iconColor: AppColors.textMuted,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppColors.deepGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example bills',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ClovaraColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See estimated out-of-pocket costs',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          children: [_buildExampleBills(plan)],
        ),
      ),
    );
  }

  Widget _buildKeyMetricChip({
    required IconData icon,
    required String label,
    required String value,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.deepGreen),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ClovaraColors.forest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExampleBills(Plan plan) {
    // High-signal, low-cognitive-load helper to understand tradeoffs.
    final engine = QuoteEngine();
    final scenarios = const <Map<String, dynamic>>[
      {'label': 'Small visit', 'amount': 500.0},
      {'label': 'Surgery', 'amount': 5000.0},
      {'label': 'Emergency', 'amount': 10000.0},
    ];

    String fmt(double v) => '\$${v.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Example bills',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Estimated out-of-pocket after deductible and reimbursement.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 560;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in scenarios)
                    SizedBox(
                      width: isWide ? (c.maxWidth - 20) / 3 : c.maxWidth,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Builder(
                          builder: (_) {
                            final amt = (s['amount'] as double);
                            final oop = engine.calculateOutOfPocket(
                              plan: plan,
                              claimAmount: amt,
                            );
                            final covered = engine.calculateCoverageAmount(
                              plan: plan,
                              claimAmount: amt,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: ClovaraColors.forest,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bill: ${fmt(amt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'You pay',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      fmt(oop),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Insurance pays',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      fmt(covered),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: ClovaraColors.clover,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedCard(dynamic plan) {
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final accent = _tierColor(plan);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s included',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These benefits are included in your policy.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 720 ? 2 : 1;
              final itemWidth = cols == 1 ? c.maxWidth : (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final f in features)
                    SizedBox(
                      width: itemWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, color: accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageCustomizerCard(Plan plan, {required bool isMobile}) {
    final ageYears = _resolveAgeYearsFromRoute();
    final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(
      riskBand: plan.riskBand,
    );
    final allowedAnnualLimits = ProductCatalog.annualLimitOptionsFor(
      riskBand: plan.riskBand,
      ageYears: ageYears,
    );

    final selectedAddOns = plan.selectedAddOns
        .map(
          (s) => AddOnType.values.firstWhere(
            (e) => e.name == s || e.toString() == s,
            orElse: () => AddOnType.examFees,
          ),
        )
        .toSet();

    int? currentAnnualLimit;
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) {
      currentAnnualLimit = null;
    } else {
      currentAnnualLimit = plan.maxAnnualCoverage.toInt();
    }

    int currentReimbursement = plan.reimbursementPercent;
    if (!allowedReimbursements.contains(currentReimbursement)) {
      currentReimbursement = allowedReimbursements.isEmpty
          ? 70
          : allowedReimbursements.last;
    }

    int currentDeductible = plan.annualDeductible.toInt();
    if (!allowedDeductibles.contains(currentDeductible)) {
      currentDeductible = allowedDeductibles.isEmpty
          ? 500
          : allowedDeductibles.first;
    }

    if (!allowedAnnualLimits.contains(currentAnnualLimit)) {
      final coerced = allowedAnnualLimits.whereType<int>().isEmpty
          ? 10000
          : (allowedAnnualLimits.whereType<int>().toList()..sort()).last;
      currentAnnualLimit = coerced;
    }

    Future<Plan> rebuild({
      int? reimbursementPercent,
      int? annualDeductible,
      int? annualLimit,
      bool annualLimitProvided = false,
      Set<AddOnType>? addOns,
    }) async {
      final nextReimb = reimbursementPercent ?? currentReimbursement;
      final nextDed = annualDeductible ?? currentDeductible;
      final nextLimit = annualLimitProvided ? annualLimit : currentAnnualLimit;
      final nextAddOns = (addOns ?? selectedAddOns).toList();

      try {
        final owner = _routeArguments?['owner'] as Owner?;
        if (owner != null) {
          final svc = PricingQuoteService();
          final priced = await svc.priceSku(
            riskBand: plan.riskBand.name,
            zipCode: owner.address.zipCode,
            state: owner.address.state,
            numberOfPets: plan.numberOfPets,
            tier: plan.type.name,
            reimbursementPercent: nextReimb,
            annualDeductible: nextDed,
            annualLimit: nextLimit,
            addOns: nextAddOns.map((e) => e.name).toList(growable: false),
          );
          if (priced != null) return priced;
        }
      } catch (_) {
        // Ignore.
      }

      final engine = QuoteEngine();
      return engine.buildPlan(
        tier: plan.type,
        basePremium: plan.pricingBasePremium,
        riskBand: plan.riskBand,
        numberOfPets: plan.numberOfPets,
        discount: plan.multiPetDiscount,
        regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
        regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
        ageYears: ageYears,
        reimbursementPercent: nextReimb,
        annualDeductible: nextDed,
        annualLimit: nextLimit,
        addOns: nextAddOns,
      );
    }

    final visibleAddOns = AddOn.all.where((addon) {
      final availability = _availability;
      if (availability == null) return true;
      return ProductCatalogAvailabilityEngine.isAddOnEnabled(
        availability,
        addon.type.name,
      );
    }).toList();

    Widget content(
      bool includeHeaderActions,
      Plan workingPlan,
      void Function(Plan next) apply,
    ) {
      final addOnLoads =
          workingPlan.pricingBreakdown?.addOnMonthlyLoads ??
          const <String, double>{};
      final currentPremium = workingPlan.monthlyPremium;
      final baseline = _baselineMonthlyPremium;
      final delta = baseline == null ? null : (currentPremium - baseline);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeHeaderActions) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customize coverage',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ClovaraColors.forest,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Adjust the levers below — your price updates instantly.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${currentPremium.toStringAsFixed(0)}/mo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: ClovaraColors.forest,
                        ),
                      ),
                      if (delta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${delta <= 0 ? '' : '+'}\$${delta.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: delta <= 0
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildOptionChips<int>(
            title: 'Reimbursement',
            subtitle: 'Higher reimbursement → higher premium',
            options: allowedReimbursements,
            selected: currentReimbursement,
            labelFor: (v) => '$v%',
            onSelected: (v) async {
              currentReimbursement = v;
              apply(await rebuild(reimbursementPercent: v));
            },
          ),
          const SizedBox(height: 12),
          _buildOptionChips<int>(
            title: 'Annual deductible',
            subtitle: 'Higher deductible → lower premium',
            options: allowedDeductibles,
            selected: currentDeductible,
            labelFor: (v) => '\$$v',
            onSelected: (v) async {
              currentDeductible = v;
              apply(await rebuild(annualDeductible: v));
            },
          ),
          const SizedBox(height: 12),
          _buildOptionChips<int?>(
            title: 'Annual limit',
            subtitle: 'More coverage → higher premium',
            options: allowedAnnualLimits,
            selected: currentAnnualLimit,
            labelFor: (v) =>
                v == null ? 'Unlimited' : '\$${(v / 1000).toStringAsFixed(0)}k',
            onSelected: (v) async {
              currentAnnualLimit = v;
              apply(await rebuild(annualLimit: v, annualLimitProvided: true));
            },
          ),
          if (includeHeaderActions && visibleAddOns.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Add-ons',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 8),
            ...visibleAddOns.map((addon) {
              final selected = selectedAddOns.contains(addon.type);
              final load = addOnLoads[addon.type.name];
              final priceLabel = load == null
                  ? null
                  : '+ \$${load.toStringAsFixed(2)}/mo';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? ClovaraColors.clover : AppColors.border,
                  ),
                ),
                child: SwitchListTile.adaptive(
                  value: selected,
                  onChanged: (nextSelected) async {
                    final next = Set<AddOnType>.from(selectedAddOns);
                    if (nextSelected) {
                      next.add(addon.type);
                    } else {
                      next.remove(addon.type);
                    }
                    apply(await rebuild(addOns: next));
                  },
                  contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          addon.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (priceLabel != null)
                        Text(
                          priceLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    addon.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ],
          if (_isLoadingAvailability)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading available products…',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: isMobile
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            Builder(
              builder: (context) {
                final baseline = _baselineMonthlyPremium;
                final currentPremium = plan.monthlyPremium;
                final delta = baseline == null
                    ? null
                    : (currentPremium - baseline);

                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: ClovaraColors.forest,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customize coverage',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: ClovaraColors.forest,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$currentReimbursement% reimbursement • \$$currentDeductible deductible • '
                              '${currentAnnualLimit == null ? 'Unlimited' : '\$${(currentAnnualLimit! / 1000).toStringAsFixed(0)}k'} annual limit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${currentPremium.toStringAsFixed(0)}/mo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: ClovaraColors.forest,
                              ),
                            ),
                            if (delta != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: delta <= 0
                                      ? AppColors.success.withValues(
                                          alpha: 0.10,
                                        )
                                      : AppColors.warning.withValues(
                                          alpha: 0.10,
                                        ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${delta <= 0 ? '' : '+'}\$${delta.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: delta <= 0
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final selected = _plans[_selectedPlanIndex];
                final working = selected is Plan ? selected : plan;
                return content(
                  false,
                  working,
                  (next) => _updateSelectedPlan(next),
                );
              },
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: ClovaraColors.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Boost your coverage',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ClovaraColors.forest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add extras now — you can adjust coverage details anytime.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your coverage settings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ClovaraColors.forest,
                    ),
                  ),
                ),
                Text(
                  '\$${plan.monthlyPremium.toStringAsFixed(0)}/mo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ClovaraColors.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$currentReimbursement% reimbursement • \$$currentDeductible deductible • '
              '${currentAnnualLimit == null ? 'Unlimited' : '\$${(currentAnnualLimit! / 1000).toStringAsFixed(0)}k'} annual limit',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _openCoverageCustomizerBottomSheet(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClovaraColors.forest,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text(
                  'Adjust deductible, reimbursement & limits',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openCoverageCustomizerBottomSheet(Plan startingPlan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        Plan workingPlan = startingPlan;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void apply(Plan next) {
              setModalState(() => workingPlan = next);
              _updateSelectedPlan(next);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SingleChildScrollView(
                  child: _buildCoverageCustomizerCardBody(
                    workingPlan: workingPlan,
                    apply: apply,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoverageCustomizerCardBody({
    required Plan workingPlan,
    required void Function(Plan next) apply,
  }) {
    // Reuse the exact logic from the card, but allow the modal to stay in sync.
    // We call the same builder as desktop uses, with header actions.
    return Builder(
      builder: (context) {
        // We route through the existing method to keep parity.
        // The method reads allowed options from ProductCatalog / route, so this is safe.
        return _buildCoverageCustomizerModalContent(workingPlan, apply);
      },
    );
  }

  Widget _buildCoverageCustomizerModalContent(
    Plan workingPlan,
    void Function(Plan next) apply,
  ) {
    // Duplicate minimal computation to avoid threading many params.
    final ageYears = _resolveAgeYearsFromRoute();
    final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(
      riskBand: workingPlan.riskBand,
    );
    final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(
      riskBand: workingPlan.riskBand,
    );
    final allowedAnnualLimits = ProductCatalog.annualLimitOptionsFor(
      riskBand: workingPlan.riskBand,
      ageYears: ageYears,
    );

    final selectedAddOns = workingPlan.selectedAddOns
        .map(
          (s) => AddOnType.values.firstWhere(
            (e) => e.name == s || e.toString() == s,
            orElse: () => AddOnType.examFees,
          ),
        )
        .toSet();

    int? currentAnnualLimit;
    if (workingPlan.isUnlimitedAnnualCoverage ||
        workingPlan.maxAnnualCoverage.isInfinite) {
      currentAnnualLimit = null;
    } else {
      currentAnnualLimit = workingPlan.maxAnnualCoverage.toInt();
    }

    int currentReimbursement = workingPlan.reimbursementPercent;
    if (!allowedReimbursements.contains(currentReimbursement)) {
      currentReimbursement = allowedReimbursements.isEmpty
          ? 70
          : allowedReimbursements.last;
    }

    int currentDeductible = workingPlan.annualDeductible.toInt();
    if (!allowedDeductibles.contains(currentDeductible)) {
      currentDeductible = allowedDeductibles.isEmpty
          ? 500
          : allowedDeductibles.first;
    }

    if (!allowedAnnualLimits.contains(currentAnnualLimit)) {
      final coerced = allowedAnnualLimits.whereType<int>().isEmpty
          ? 10000
          : (allowedAnnualLimits.whereType<int>().toList()..sort()).last;
      currentAnnualLimit = coerced;
    }

    Future<Plan> rebuild({
      int? reimbursementPercent,
      int? annualDeductible,
      int? annualLimit,
      bool annualLimitProvided = false,
      Set<AddOnType>? addOns,
    }) async {
      final nextReimb = reimbursementPercent ?? currentReimbursement;
      final nextDed = annualDeductible ?? currentDeductible;
      final nextLimit = annualLimitProvided ? annualLimit : currentAnnualLimit;
      final nextAddOns = (addOns ?? selectedAddOns).toList();

      try {
        final owner = _routeArguments?['owner'] as Owner?;
        if (owner != null) {
          final svc = PricingQuoteService();
          final priced = await svc.priceSku(
            riskBand: workingPlan.riskBand.name,
            zipCode: owner.address.zipCode,
            state: owner.address.state,
            numberOfPets: workingPlan.numberOfPets,
            tier: workingPlan.type.name,
            reimbursementPercent: nextReimb,
            annualDeductible: nextDed,
            annualLimit: nextLimit,
            addOns: nextAddOns.map((e) => e.name).toList(growable: false),
          );
          if (priced != null) return priced;
        }
      } catch (_) {
        // Ignore.
      }

      final engine = QuoteEngine();
      return engine.buildPlan(
        tier: workingPlan.type,
        basePremium: workingPlan.pricingBasePremium,
        riskBand: workingPlan.riskBand,
        numberOfPets: workingPlan.numberOfPets,
        discount: workingPlan.multiPetDiscount,
        regionalMultiplier:
            workingPlan.pricingBreakdown?.regionalMultiplier ?? 1.0,
        regionalKey: workingPlan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
        ageYears: ageYears,
        reimbursementPercent: nextReimb,
        annualDeductible: nextDed,
        annualLimit: nextLimit,
        addOns: nextAddOns,
      );
    }

    final visibleAddOns = AddOn.all.where((addon) {
      final availability = _availability;
      if (availability == null) return true;
      return ProductCatalogAvailabilityEngine.isAddOnEnabled(
        availability,
        addon.type.name,
      );
    }).toList();

    final addOnLoads =
        workingPlan.pricingBreakdown?.addOnMonthlyLoads ??
        const <String, double>{};

    final baseline = _baselineMonthlyPremium;
    final delta = baseline == null
        ? null
        : (workingPlan.monthlyPremium - baseline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Customize coverage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ClovaraColors.forest,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current price',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${workingPlan.monthlyPremium.toStringAsFixed(0)}/mo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ClovaraColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${delta <= 0 ? '' : '+'}\$${delta.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: delta <= 0 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildOptionChips<int>(
          title: 'Reimbursement',
          subtitle: 'Higher reimbursement → higher premium',
          options: allowedReimbursements,
          selected: currentReimbursement,
          labelFor: (v) => '$v%',
          onSelected: (v) async {
            currentReimbursement = v;
            apply(await rebuild(reimbursementPercent: v));
          },
        ),
        const SizedBox(height: 12),
        _buildOptionChips<int>(
          title: 'Annual deductible',
          subtitle: 'Higher deductible → lower premium',
          options: allowedDeductibles,
          selected: currentDeductible,
          labelFor: (v) => '\$$v',
          onSelected: (v) async {
            currentDeductible = v;
            apply(await rebuild(annualDeductible: v));
          },
        ),
        const SizedBox(height: 12),
        _buildOptionChips<int?>(
          title: 'Annual limit',
          subtitle: 'More coverage → higher premium',
          options: allowedAnnualLimits,
          selected: currentAnnualLimit,
          labelFor: (v) =>
              v == null ? 'Unlimited' : '\$${(v / 1000).toStringAsFixed(0)}k',
          onSelected: (v) async {
            currentAnnualLimit = v;
            apply(await rebuild(annualLimit: v, annualLimitProvided: true));
          },
        ),
        if (visibleAddOns.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Add-ons',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          ...visibleAddOns.map((addon) {
            final selected = selectedAddOns.contains(addon.type);
            final load = addOnLoads[addon.type.name];
            final priceLabel = load == null
                ? null
                : '+ \$${load.toStringAsFixed(2)}/mo';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? ClovaraColors.clover : AppColors.border,
                ),
              ),
              child: SwitchListTile.adaptive(
                value: selected,
                onChanged: (nextSelected) async {
                  final next = Set<AddOnType>.from(selectedAddOns);
                  if (nextSelected) {
                    next.add(addon.type);
                  } else {
                    next.remove(addon.type);
                  }
                  apply(await rebuild(addOns: next));
                },
                contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        addon.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (priceLabel != null)
                      Text(
                        priceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  addon.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
        if (_isLoadingAvailability)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading available products…',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionChips<T>({
    required String title,
    required String subtitle,
    required List<T> options,
    required T selected,
    required String Function(T v) labelFor,
    required void Function(T v) onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final opt in options)
                ChoiceChip(
                  label: Text(
                    labelFor(opt),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  selected: opt == selected,
                  onSelected: (_) => onSelected(opt),
                  selectedColor: AppColors.surface2,
                  side: BorderSide(
                    color: opt == selected
                        ? ClovaraColors.clover
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: ClovaraColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ClovaraColors.forest,
                  ),
                ),
                Text(
                  'Select the coverage that works best',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _buildAccountIcon(context),
        ],
      ),
    );
  }

  Future<void> _showSaveResumeCode(BuildContext context) async {
    await SaveResumeDialog.show(
      context,
      ensureSaved: () async {
        final Pet? pet = _routeArguments?['pet'] ?? _routeArguments?['petData'];
        final RiskScore? riskScore = _routeArguments?['riskScore'];
        final List<UnderwritingExclusion>? exclusions = _routeArguments?['exclusions'];
        final Owner? owner = _routeArguments?['owner'];
          
        Map<String, dynamic> quoteData = {
          'step': 'PLAN_SELECTION',
          if (pet != null) 'pet': pet, // Assumes Pet has toJson
          if (riskScore != null) 'riskScore': riskScore.toJson(),
          if (exclusions != null) 'exclusions': exclusions.map((e) => e.toJson()).toList(),
          if (owner != null) 'owner': owner.toJson(),
        };

        await UserSessionService().savePendingQuote(quoteData);

        // Also save to backend draft for cross-device retrieval
        await DraftService().upsertQuoteDraft(quoteData: quoteData);
      },
      title: 'Save & resume later',
      body:
          'We’ll save your plan selection progress. Use this code to resume from the home page on any device.',
      copyLabel: 'Copy code',
      doneLabel: 'Done',
    );
  }

  Widget _buildAccountIcon(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Authenticated user: show Dashboard and Sign Out
        if (snapshot.hasData) {
          return PopupMenuButton<String>(
            icon: Icon(
              Icons.account_circle,
              color: ClovaraColors.forest,
              size: 28,
            ),
            onSelected: (value) {
              if (value == 'dashboard') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CustomerHomeScreen(isPremium: false),
                  ),
                );
              } else if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
              const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          );
        }
        
        // Unauthenticated user: show Save for Later and Home
        return PopupMenuButton<String>(
            icon: Icon(
              Icons.account_circle_outlined, // Outlined to indicate guest/unauth
              color: ClovaraColors.forest,
              size: 28,
            ),
             onSelected: (value) {
              if (value == 'save') {
                _showSaveResumeCode(context);
              } else if (value == 'home') {
                 context.go('/');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save', 
                child: Row(
                  children: [
                    Icon(Icons.bookmark_border, size: 20, color: AppColors.text),
                    SizedBox(width: 8),
                    Text('Save for later'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'home', 
                child: Row(
                  children: [
                    Icon(Icons.home_outlined, size: 20, color: AppColors.text),
                    SizedBox(width: 8),
                    Text('Return to Home'),
                  ],
                ),
              ),
            ],
          );
      },
    );
  }

  // ignore: unused_element
  Widget _buildMobileView() {
    final selected = _plans[_selectedPlanIndex];
    return Column(
      children: [
        _buildPlanTabs(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExclusionsCallout(),
                      _buildPlanDetails(selected, _selectedPlanIndex),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
              if (selected is Plan) _buildStickyCustomizationSheet(selected),
            ],
          ),
        ),
        _buildContinueButton(),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildDesktopView() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_plans.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < _plans.length - 1 ? 16 : 0,
                    ),
                    child: _buildPlanColumn(_plans[index], index),
                  ),
                );
              }),
            ),
          ),
        ),
        _buildExclusionsCallout(),
        if (_plans[_selectedPlanIndex] is Plan)
          _buildCustomizationPanel(_plans[_selectedPlanIndex] as Plan),
        Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildContinueButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(_plans.length, (index) {
          final plan = _plans[index];
          final name = plan is Plan ? plan.name : (plan as PlanData).name;
          final selected = _selectedPlanIndex == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < _plans.length - 1 ? 8 : 0,
              ),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPlanIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? ClovaraColors.clover
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanDetails(dynamic plan, int index) {
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final color = plan is PlanData ? plan.color : ClovaraColors.clover;
    final deductible = plan is Plan
        ? plan.annualDeductible.toInt()
        : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan
        ? (100 - plan.coPayPercentage).toInt()
        : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan
        ? _formatAnnualLimit(plan)
        : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final recommended =
        riskScore != null &&
        index == _getRecommendedPlanIndex(riskScore, _plans.length);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/month',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (recommended) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ClovaraColors.clover,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'AI RECOMMENDED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              _buildStat('$reimburse%', 'Reimbursement', color),
              const SizedBox(width: 16),
              _buildStat(limitLabel, 'Annual Limit', color),
              const SizedBox(width: 16),
              _buildStat('\$$deductible', 'Deductible', color),
            ],
          ),
          if (plan is Plan) ...[
            const SizedBox(height: 18),
            _buildPricingBreakdownSection(plan, color),
          ],
          const SizedBox(height: 32),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 24),
          Text(
            'What\'s Included',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanColumn(dynamic plan, int index) {
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final color = plan is PlanData ? plan.color : ClovaraColors.clover;
    final deductible = plan is Plan
        ? plan.annualDeductible.toInt()
        : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan
        ? (100 - plan.coPayPercentage).toInt()
        : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan
        ? _formatAnnualLimit(plan)
        : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final recommended =
        riskScore != null &&
        index == _getRecommendedPlanIndex(riskScore, _plans.length);
    final selected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ClovaraColors.forest,
              ),
            ),
            if (recommended) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ClovaraColors.clover,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/mo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildCompactStat('$reimburse%', 'Reimbursement', color),
            const SizedBox(height: 12),
            _buildCompactStat(limitLabel, 'Annual Limit', color),
            const SizedBox(height: 12),
            _buildCompactStat('\$$deductible', 'Deductible', color),
            const SizedBox(height: 24),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: features.length,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          features[i],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                selected ? 'SELECTED' : 'SELECT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String value, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final plan = _plans[_selectedPlanIndex];
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            context.push(
              '/checkout',
              extra: {
                'pet':
                    _routeArguments?['petData'] ??
                    _routeArguments?['pet'] ??
                    {},
                'selectedPlan': _plans[_selectedPlanIndex],
                'riskScore': _routeArguments?['riskScore'],
                'underwritingCaseId': _routeArguments?['underwritingCaseId'],
                'exclusions':
                    _routeArguments?['exclusions'] ??
                    _routeArguments?['excludedConditions'],
                'underwritingSnapshot':
                    _routeArguments?['underwritingSnapshot'],
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: ClovaraColors.clover,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Continue with $name • \$${price.toStringAsFixed(0)}/mo',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class PlanData {
  final String name;
  final double monthlyPrice;
  final int annualDeductible;
  final int reimbursement;
  final int annualLimit;
  final List<String> features;
  final Color color;
  final bool isPopular;

  PlanData({
    required this.name,
    required this.monthlyPrice,
    required this.annualDeductible,
    required this.reimbursement,
    required this.annualLimit,
    required this.features,
    required this.color,
    this.isPopular = false,
  });
}

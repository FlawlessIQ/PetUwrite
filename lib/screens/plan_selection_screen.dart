import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/risk_score.dart';
import '../models/owner.dart';
import '../services/quote_engine.dart';
import '../services/product_catalog.dart';
import '../services/product_catalog_availability_engine.dart';
import '../theme/clovara_theme.dart';

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

  final ProductCatalogAvailabilityEngine _productAvailability = ProductCatalogAvailabilityEngine();
  Map<String, dynamic>? _availability;
  bool _isLoadingAvailability = true;

  List<String> _getExclusionNamesFromRoute() {
    final raw = _routeArguments?['exclusions'] ?? _routeArguments?['excludedConditions'];
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

  Widget _buildExclusionsCallout() {
    final exclusions = _getExclusionNamesFromRoute();
    if (exclusions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Coverage exclusions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your policy will not cover treatment related to these conditions:',
            style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: exclusions
                .map(
                  (e) => Chip(
                    label: Text(
                      e,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.orange.shade200),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
  
  @override
  void initState() {
    super.initState();
    _loadAvailability();
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
    if (availability == null) return plans;
    return plans
        .where((p) => ProductCatalogAvailabilityEngine.isTierEnabled(availability, p.type.name))
        .toList();
  }

  void _applyAvailabilityToPlans() {
    if (_dynamicPlans == null) return;
    final filtered = _filterPlansByAvailability(_dynamicPlans!);
    if (filtered.isEmpty) return;

    // Keep selection stable if possible.
    final selected = (_selectedPlanIndex >= 0 && _selectedPlanIndex < _dynamicPlans!.length)
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
      _routeArguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _generatePlans();
    }
  }
  
  void _generatePlans() {
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final owner = _routeArguments?['owner'] as Owner?;
    
    if (riskScore != null && owner != null) {
      try {
        final quoteEngine = QuoteEngine();
        final ageYears = _resolveAgeYearsFromRoute();
        final plans = quoteEngine.generateQuote(
          riskScore: riskScore,
          zipCode: owner.address.zipCode,
          state: owner.address.state,
          numberOfPets: 1,
          ageYears: ageYears,
        );

        final filtered = _filterPlansByAvailability(plans);
        // Recommended defaults: Standard if available, else first.
        final recommendedPlanType = filtered.any((p) => p.type == PlanType.standard)
            ? PlanType.standard
            : filtered.first.type;
        final recommendedIndex = filtered.indexWhere((p) => p.type == recommendedPlanType);
        
        setState(() {
          _dynamicPlans = filtered;
          _isLoadingPlans = false;
          _selectedPlanIndex = recommendedIndex >= 0 ? recommendedIndex : 0;
        });
      } catch (e) {
        setState(() => _isLoadingPlans = false);
      }
    } else {
      setState(() => _isLoadingPlans = false);
    }
  }

  String _formatAnnualLimit(Plan plan) {
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) return 'Unlimited';
    return '\$${(plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}k';
  }

  void _updateSelectedPlan(Plan updated) {
    if (_dynamicPlans == null) return;
    setState(() {
      _dynamicPlans = List<Plan>.from(_dynamicPlans!);
      _dynamicPlans![_selectedPlanIndex] = updated;
    });
  }

  int? _resolveAgeYearsFromRoute() {
    final args = _routeArguments;
    if (args == null) return null;

    // Common shapes: {pet: Pet}, {petData: Map}, {ageYears: int}, etc.
    dynamic v = args['ageYears'] ?? args['petAgeYears'] ?? args['petAge'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());

    final pet = args['pet'] ?? args['petData'] ?? args['pet_profile'] ?? args['profile'];
    if (pet is Map) {
      final raw = pet['ageYears'] ?? pet['age_years'] ?? pet['age'] ?? pet['petAgeYears'];
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
        .map((s) => AddOnType.values.firstWhere(
              (e) => e.name == s || e.toString() == s,
              orElse: () => AddOnType.examFees,
            ))
        .toSet();

    int? currentAnnualLimit;
    if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) {
      currentAnnualLimit = null;
    } else {
      currentAnnualLimit = plan.maxAnnualCoverage.toInt();
    }

    final ageYears = _resolveAgeYearsFromRoute();

    final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(riskBand: plan.riskBand);
    final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(riskBand: plan.riskBand);
    final allowedAnnualLimits = ProductCatalog.annualLimitOptionsFor(
      riskBand: plan.riskBand,
      ageYears: ageYears,
    );

    int currentReimbursement = plan.reimbursementPercent;
    if (!allowedReimbursements.contains(currentReimbursement)) {
      currentReimbursement = allowedReimbursements.isEmpty ? 70 : allowedReimbursements.last;
    }

    int currentDeductible = plan.annualDeductible.toInt();
    if (!allowedDeductibles.contains(currentDeductible)) {
      currentDeductible = allowedDeductibles.isEmpty ? 500 : allowedDeductibles.first;
    }

    // If current selection is no longer allowed, coerce to max finite.
    if (!allowedAnnualLimits.contains(currentAnnualLimit)) {
      final coerced = allowedAnnualLimits.whereType<int>().isEmpty
          ? 10000
          : (allowedAnnualLimits.whereType<int>().toList()..sort()).last;
      currentAnnualLimit = coerced;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize coverage',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoadingAvailability)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Reimbursement
          _buildInlineDropdown<int>(
            label: 'Reimbursement',
            value: currentReimbursement,
            options: allowedReimbursements,
            display: (v) => '$v%',
            onChanged: (v) {
              final engine = QuoteEngine();
              final updated = engine.buildPlan(
                tier: plan.type,
                basePremium: plan.pricingBasePremium,
                riskBand: plan.riskBand,
                numberOfPets: plan.numberOfPets,
                discount: plan.multiPetDiscount,
                regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
                regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
                ageYears: ageYears,
                reimbursementPercent: v,
                annualDeductible: currentDeductible,
                annualLimit: currentAnnualLimit,
                addOns: selectedAddOns.toList(),
              );
              _updateSelectedPlan(updated);
            },
          ),

          const SizedBox(height: 10),

          // Deductible
          _buildInlineDropdown<int>(
            label: 'Annual deductible',
            value: currentDeductible,
            options: allowedDeductibles,
            display: (v) => '\$$v',
            onChanged: (v) {
              final engine = QuoteEngine();
              final updated = engine.buildPlan(
                tier: plan.type,
                basePremium: plan.pricingBasePremium,
                riskBand: plan.riskBand,
                numberOfPets: plan.numberOfPets,
                discount: plan.multiPetDiscount,
                regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
                regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
                ageYears: ageYears,
                reimbursementPercent: currentReimbursement,
                annualDeductible: v,
                annualLimit: currentAnnualLimit,
                addOns: selectedAddOns.toList(),
              );
              _updateSelectedPlan(updated);
            },
          ),

          const SizedBox(height: 10),

          // Annual limit
          _buildInlineDropdown<int?>(
            label: 'Annual limit',
            value: currentAnnualLimit,
            options: allowedAnnualLimits,
            display: (v) => v == null ? 'Unlimited' : '\$${(v / 1000).toStringAsFixed(0)}k',
            onChanged: (v) {
              final engine = QuoteEngine();
              final updated = engine.buildPlan(
                tier: plan.type,
                basePremium: plan.pricingBasePremium,
                riskBand: plan.riskBand,
                numberOfPets: plan.numberOfPets,
                discount: plan.multiPetDiscount,
                regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
                regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
                ageYears: ageYears,
                reimbursementPercent: currentReimbursement,
                annualDeductible: currentDeductible,
                annualLimit: v,
                addOns: selectedAddOns.toList(),
              );
              _updateSelectedPlan(updated);
            },
          ),

          const SizedBox(height: 14),

          Text(
            'Add-ons',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AddOn.all
                .where((addon) {
                  final availability = _availability;
                  if (availability == null) return true;
                  return ProductCatalogAvailabilityEngine.isAddOnEnabled(availability, addon.type.name);
                })
                .map((addon) {
              final selected = selectedAddOns.contains(addon.type);
              return FilterChip(
                selected: selected,
                label: Text(addon.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onSelected: (v) {
                  final next = Set<AddOnType>.from(selectedAddOns);
                  if (v) {
                    next.add(addon.type);
                  } else {
                    next.remove(addon.type);
                  }

                  final engine = QuoteEngine();
                  final updated = engine.buildPlan(
                    tier: plan.type,
                    basePremium: plan.pricingBasePremium,
                    riskBand: plan.riskBand,
                    numberOfPets: plan.numberOfPets,
                    discount: plan.multiPetDiscount,
                    regionalMultiplier: plan.pricingBreakdown?.regionalMultiplier ?? 1.0,
                    regionalKey: plan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
                    ageYears: ageYears,
                    reimbursementPercent: plan.reimbursementPercent,
                    annualDeductible: plan.annualDeductible.toInt(),
                    annualLimit: currentAnnualLimit,
                    addOns: next.toList(),
                  );
                  _updateSelectedPlan(updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ClovaraColors.forest),
          ),
          subtitle: Text(
            '$versionLabel • ${breakdown.effectiveDateIso}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          children: [
            _buildBreakdownRow('Base risk rate', fmtMoney(breakdown.baseRiskRate)),
            _buildBreakdownRow('Risk band', '${breakdown.riskBand.name} (×${breakdown.riskBandMultiplier.toStringAsFixed(2)})'),
            _buildBreakdownRow('Region', '${breakdown.regionalKey} (×${breakdown.regionalMultiplier.toStringAsFixed(2)})'),
            _buildBreakdownRow('Multi-pet discount', '${(breakdown.multiPetDiscount * 100).toStringAsFixed(0)}%'),
            _buildBreakdownRow('Pricing base premium', fmtMoney(breakdown.pricingBasePremium)),
            _buildBreakdownRow('Reimbursement', '${breakdown.reimbursementPercent}% (×${breakdown.reimbursementFactor.toStringAsFixed(2)})'),
            _buildBreakdownRow('Deductible', '\$${breakdown.annualDeductible} (×${breakdown.deductibleFactor.toStringAsFixed(2)})'),
            _buildBreakdownRow(
              'Annual limit',
              '${breakdown.annualLimit == null ? 'Unlimited' : '\$${breakdown.annualLimit}'} (×${breakdown.annualLimitFactor.toStringAsFixed(2)})',
            ),
            const SizedBox(height: 8),
            _buildBreakdownRow('Premium before add-ons', fmtMoney(breakdown.premiumBeforeAddOns)),
            if (addOns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Add-ons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
              const SizedBox(height: 6),
              ...addOns.map((e) => _buildBreakdownRow(e.key, '+ ${fmtMoney(e.value)}')),
            ],
            const SizedBox(height: 8),
            _buildBreakdownRow('Add-on total', '+ ${fmtMoney(breakdown.addOnTotal)}'),
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
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
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
              valueStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDropdown<T>({
    required String label,
    required T value,
    required List<T> options,
    required String Function(T v) display,
    required void Function(T v) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ),
        DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          items: options
              .map(
                (o) => DropdownMenuItem<T>(
                  value: o,
                  child: Text(display(o), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ],
    );
  }
  
  int _getRecommendedPlanIndex(RiskScore riskScore) {
    switch (riskScore.riskLevel) {
      case RiskLevel.low:
        return 0;
      case RiskLevel.medium:
        return 1;
      case RiskLevel.high:
      case RiskLevel.veryHigh:
        return 2;
    }
  }
  
  List<dynamic> get _plans => _dynamicPlans != null && _dynamicPlans!.isNotEmpty
      ? _dynamicPlans!
      : _staticPlans;
  
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
      color: ClovaraColors.sunset,
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
      color: ClovaraColors.kWarmCoral,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    
    if (_isLoadingPlans) {
      return Scaffold(
        backgroundColor: Colors.white,
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: isMobile ? _buildMobileView() : _buildDesktopView(),
          ),
        ],
      ),
    );
  }
  
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildAccountIcon(context),
        ],
      ),
    );
  }
  
  Widget _buildAccountIcon(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return PopupMenuButton<String>(
            icon: Icon(Icons.account_circle, color: ClovaraColors.forest, size: 28),
            onSelected: (value) {
              if (value == 'dashboard') {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const CustomerHomeScreen(isPremium: false),
                ));
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
        return IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          )),
          icon: Icon(Icons.login, color: ClovaraColors.forest),
        );
      },
    );
  }
  
  Widget _buildMobileView() {
    return Column(
      children: [
        _buildPlanTabs(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExclusionsCallout(),
                if (_plans[_selectedPlanIndex] is Plan)
                  _buildCustomizationPanel(_plans[_selectedPlanIndex] as Plan),
                _buildPlanDetails(_plans[_selectedPlanIndex], _selectedPlanIndex),
              ],
            ),
          ),
        ),
        _buildContinueButton(),
      ],
    );
  }
  
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
                    padding: EdgeInsets.only(right: index < _plans.length - 1 ? 16 : 0),
                    child: _buildPlanColumn(_plans[index], index),
                  ),
                );
              }),
            ),
          ),
        ),
        _buildExclusionsCallout(),
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
              padding: EdgeInsets.only(right: index < _plans.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPlanIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? ClovaraColors.clover : Colors.grey.shade100,
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
    final price = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final color = plan is PlanData ? plan.color : ClovaraColors.clover;
    final deductible = plan is Plan ? plan.annualDeductible.toInt() : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan ? (100 - plan.coPayPercentage).toInt() : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan ? _formatAnnualLimit(plan) : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final recommended = riskScore != null && index == _getRecommendedPlanIndex(riskScore);
    
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
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.5),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildPlanColumn(dynamic plan, int index) {
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final color = plan is PlanData ? plan.color : ClovaraColors.clover;
    final deductible = plan is Plan ? plan.annualDeductible.toInt() : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan ? (100 - plan.coPayPercentage).toInt() : (plan as PlanData).reimbursement;
    final limitLabel = plan is Plan ? _formatAnnualLimit(plan) : '\$${((plan as PlanData).annualLimit / 1000).toStringAsFixed(0)}k';
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final recommended = riskScore != null && index == _getRecommendedPlanIndex(riskScore);
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
          boxShadow: selected ? [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4)),
          ] : [],
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
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
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
  
  Widget _buildContinueButton() {
    final plan = _plans[_selectedPlanIndex];
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    
    return Container(
      margin: const EdgeInsets.all(20),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/checkout',
            arguments: {
              'pet': _routeArguments?['petData'] ?? _routeArguments?['pet'] ?? {},
              'selectedPlan': _plans[_selectedPlanIndex],
              'riskScore': _routeArguments?['riskScore'],
              'underwritingCaseId': _routeArguments?['underwritingCaseId'],
              'exclusions': _routeArguments?['exclusions'] ?? _routeArguments?['excludedConditions'],
              'underwritingSnapshot': _routeArguments?['underwritingSnapshot'],
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ClovaraColors.clover,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          'Continue with $name • \$${price.toStringAsFixed(0)}/mo',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

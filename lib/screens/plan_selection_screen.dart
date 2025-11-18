import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/risk_score.dart';
import '../models/owner.dart';
import '../services/quote_engine.dart';
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
  
  @override
  void initState() {
    super.initState();
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
        final plans = quoteEngine.generateQuote(
          riskScore: riskScore,
          zipCode: owner.address.zipCode,
          state: owner.address.state,
          numberOfPets: 1,
        );
        
        setState(() {
          _dynamicPlans = plans;
          _isLoadingPlans = false;
          _selectedPlanIndex = _getRecommendedPlanIndex(riskScore);
        });
      } catch (e) {
        setState(() => _isLoadingPlans = false);
      }
    } else {
      setState(() => _isLoadingPlans = false);
    }
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
      annualLimit: 5000,
      features: [
        'Accidents & Illnesses',
        '70% Reimbursement',
        '\$5,000 Annual Limit',
        '\$500 Deductible',
        '24/7 Vet Helpline',
      ],
      color: ClovaraColors.sunset,
    ),
    PlanData(
      name: 'Plus',
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
      name: 'Elite',
      monthlyPrice: 79.99,
      annualDeductible: 100,
      reimbursement: 90,
      annualLimit: 20000,
      features: [
        'Accidents & Illnesses',
        '90% Reimbursement',
        '\$20,000 Annual Limit',
        '\$100 Deductible',
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
            child: _buildPlanDetails(_plans[_selectedPlanIndex], _selectedPlanIndex),
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
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final color = plan is PlanData ? plan.color : ClovaraColors.clover;
    final deductible = plan is Plan ? plan.annualDeductible.toInt() : (plan as PlanData).annualDeductible;
    final reimburse = plan is Plan ? (100 - plan.coPayPercentage).toInt() : (plan as PlanData).reimbursement;
    final limit = plan is Plan ? plan.maxAnnualCoverage.toInt() : (plan as PlanData).annualLimit;
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
              _buildStat('\$${(limit / 1000).toStringAsFixed(0)}k', 'Annual Limit', color),
              const SizedBox(width: 16),
              _buildStat('\$$deductible', 'Deductible', color),
            ],
          ),
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
    final limit = plan is Plan ? plan.maxAnnualCoverage.toInt() : (plan as PlanData).annualLimit;
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
            _buildCompactStat('\$${(limit / 1000).toStringAsFixed(0)}k', 'Annual Limit', color),
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

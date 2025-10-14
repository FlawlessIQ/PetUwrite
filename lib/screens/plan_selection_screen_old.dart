import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/risk_score.dart';
import '../models/owner.dart';
import '../services/quote_engine.dart';
import '../theme/petuwrite_theme.dart';

/// Plan selection screen for choosing insurance coverage
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> with SingleTickerProviderStateMixin {
  int _selectedPlanIndex = 1; // Default to Plus (middle) plan
  Map<String, dynamic>? _routeArguments;
  List<Plan>? _dynamicPlans;
  bool _isLoadingPlans = true;
  late PageController _pageController;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 1,
      viewportFraction: 0.85,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get data from route arguments
    if (_routeArguments == null) {
      _routeArguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _generatePlans();
    }
  }
  
  /// Generate personalized plans using QuoteEngine
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
          
          // Set recommended plan based on risk level
          _selectedPlanIndex = _getRecommendedPlanIndex(riskScore);
        });
      } catch (e) {
        print('Error generating plans: $e');
        setState(() {
          _isLoadingPlans = false;
        });
      }
    } else {
      // Fallback to static plans if no risk score
      setState(() {
        _isLoadingPlans = false;
      });
    }
  }
  
  /// Get recommended plan index based on risk level
  int _getRecommendedPlanIndex(RiskScore riskScore) {
    switch (riskScore.riskLevel) {
      case RiskLevel.low:
        return 0; // Basic
      case RiskLevel.medium:
        return 1; // Plus
      case RiskLevel.high:
      case RiskLevel.veryHigh:
        return 2; // Elite
    }
  }
  
  /// Get the list of plans to display (dynamic or fallback to static)
  List<dynamic> get _plans {
    if (_dynamicPlans != null && _dynamicPlans!.isNotEmpty) {
      return _dynamicPlans!;
    }
    
    // Fallback to static plans
    return _staticPlans;
  }
  
  // Static fallback plans (if risk scoring fails)
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
      color: PetUwriteColors.kAccentSky,
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
      color: PetUwriteColors.kSecondaryTeal,
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
      color: PetUwriteColors.kWarmCoral,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Show loading if still calculating plans
    if (_isLoadingPlans) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PetUwriteColors.kPrimaryNavy,
                PetUwriteColors.kPrimaryNavy.withOpacity(0.9),
                PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                              PetUwriteColors.kSecondaryTeal.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(PetUwriteColors.kSecondaryTeal),
                            strokeWidth: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Generating personalized plans...',
                    style: PetUwriteTypography.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analyzing your pet\'s risk profile with AI',
                    style: PetUwriteTypography.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: PetUwriteColors.kSecondaryTeal,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI-Powered Recommendations',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
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
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF8F9FA),
              Colors.white,
              const Color(0xFFF8F9FA),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(context),
              
              // Plan Carousel
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    
                    // Carousel
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedPlanIndex = index;
                          });
                        },
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = _pageController.page! - index;
                                value = (1 - (value.abs() * 0.12)).clamp(0.88, 1.0);
                              }
                              return Center(
                                child: Transform.scale(
                                  scale: Curves.easeInOut.transform(value),
                                  child: Opacity(
                                    opacity: Curves.easeInOut.transform(value),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: _buildPlanCard(_plans[index], index),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Navigation Arrows
                    _buildNavigationArrows(),
                    
                    const SizedBox(height: 16),
                    
                    // Page Indicators
                    _buildPageIndicators(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              
              // Bottom CTA
              _buildBottomCTA(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PetUwriteColors.kPrimaryNavy,
            PetUwriteColors.kPrimaryNavy.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.account_circle, color: Colors.white, size: 24),
                          tooltip: 'Account',
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'dashboard') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CustomerHomeScreen(isPremium: false),
                                ),
                              );
                            } else if (value == 'logout') {
                              FirebaseAuth.instance.signOut();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'dashboard',
                              child: Row(
                                children: [
                                  Icon(Icons.dashboard_rounded, size: 20, color: PetUwriteColors.kPrimaryNavy),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      snapshot.data?.email ?? 'My Account',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text('Sign Out', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: PetUwriteColors.kSecondaryTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Plan',
                      style: PetUwriteTypography.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tailored coverage for your pet',
                      style: PetUwriteTypography.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: PetUwriteColors.kSecondaryTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI-Powered Recommendations',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationArrows() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Arrow
          _buildArrowButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: _selectedPlanIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
          
          // Right Arrow
          _buildArrowButton(
            icon: Icons.arrow_forward_ios,
            onPressed: _selectedPlanIndex < _plans.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
  
  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: isEnabled 
            ? LinearGradient(
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: !isEnabled ? Colors.grey.shade200 : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: isEnabled
              ? PetUwriteColors.kSecondaryTeal.withOpacity(0.4)
              : Colors.grey.shade300,
          width: 2.5,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(29),
          splashColor: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
          highlightColor: PetUwriteColors.kSecondaryTeal.withOpacity(0.1),
          child: Center(
            child: Icon(
              icon,
              color: isEnabled
                  ? PetUwriteColors.kSecondaryTeal
                  : Colors.grey.shade400,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_plans.length, (index) {
        final isSelected = _selectedPlanIndex == index;
        final plan = _plans[index];
        final planColor = plan is PlanData ? plan.color : PetUwriteColors.kSecondaryTeal;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isSelected ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      planColor,
                      planColor.withOpacity(0.8),
                    ],
                  )
                : null,
            color: !isSelected ? Colors.grey.shade300 : null,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: planColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
  
  Widget _buildPlanCard(dynamic plan, int index) {
    final isSelected = _selectedPlanIndex == index;
    
    // Extract plan details (works for both Plan and PlanData)
    final planName = plan is Plan ? plan.name : (plan as PlanData).name;
    final monthlyPrice = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    final features = plan is Plan ? plan.features : (plan as PlanData).features;
    final planColor = plan is PlanData ? plan.color : PetUwriteColors.kSecondaryTeal;
    final isPopular = plan is PlanData ? plan.isPopular : false;
    final riskScore = _routeArguments?['riskScore'] as RiskScore?;
    final isRecommended = riskScore != null && index == _getRecommendedPlanIndex(riskScore);
    
    // Get deductible and reimbursement
    final deductible = plan is Plan ? plan.annualDeductible.toInt() : (plan as PlanData).annualDeductible;
    final reimbursement = plan is Plan ? (100 - plan.coPayPercentage).toInt() : (plan as PlanData).reimbursement;
    final annualLimit = plan is Plan ? plan.maxAnnualCoverage.toInt() : (plan as PlanData).annualLimit;
    
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
                ? planColor.withOpacity(0.6)
                : Colors.grey.shade200,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: planColor.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: planColor.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header with gradient
              Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    planColor.withOpacity(0.08),
                    planColor.withOpacity(0.03),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planName,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: PetUwriteColors.kPrimaryNavy,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isRecommended || isPopular) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isRecommended
                                      ? LinearGradient(
                                          colors: [
                                            PetUwriteColors.kSecondaryTeal,
                                            PetUwriteColors.kSecondaryTeal.withOpacity(0.85),
                                          ],
                                        )
                                      : null,
                                  color: isPopular ? planColor.withOpacity(0.15) : null,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isPopular
                                      ? Border.all(
                                          color: planColor.withOpacity(0.4),
                                          width: 1.5,
                                        )
                                      : null,
                                  boxShadow: isRecommended
                                      ? [
                                          BoxShadow(
                                            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRecommended ? Icons.auto_awesome : Icons.star_rounded,
                                      color: isRecommended ? Colors.white : planColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isRecommended ? 'AI RECOMMENDED' : 'MOST POPULAR',
                                      style: TextStyle(
                                        color: isRecommended ? Colors.white : planColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: planColor.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: planColor.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: planColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${monthlyPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: planColor,
                          height: 1,
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
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Key Stats - Premium cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildPremiumStatCard(
                    '$reimbursement%',
                    'Reimbursement',
                    Icons.percent_rounded,
                    planColor,
                  ),
                  const SizedBox(width: 12),
                  _buildPremiumStatCard(
                    '\$${(annualLimit / 1000).toStringAsFixed(0)}k',
                    'Annual Limit',
                    Icons.trending_up_rounded,
                    planColor,
                  ),
                  const SizedBox(width: 12),
                  _buildPremiumStatCard(
                    '\$$deductible',
                    'Deductible',
                    Icons.monetization_on_rounded,
                    planColor,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Features - Premium list with divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: planColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.checklist_rounded,
                            color: planColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'What\'s Included',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: PetUwriteColors.kPrimaryNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...features.asMap().entries.map((entry) {
                      final index = entry.key;
                      final feature = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 1),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    planColor.withOpacity(0.15),
                                    planColor.withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: planColor.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: planColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (index < features.length - 1) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      );
  }
  
  Widget _buildPremiumStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomCTA() {
    final plan = _plans[_selectedPlanIndex];
    final planName = plan is Plan ? plan.name : (plan as PlanData).name;
    final monthlyPrice = plan is Plan ? plan.monthlyPremium : (plan as PlanData).monthlyPrice;
    final planColor = plan is PlanData ? plan.color : PetUwriteColors.kSecondaryTeal;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plan Summary - Premium design
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      planColor.withOpacity(0.10),
                      planColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: planColor.withOpacity(0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: planColor.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: planColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: planColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: PetUwriteColors.kPrimaryNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your selected coverage',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${monthlyPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: planColor,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // CTA Button - Premium gradient design
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PetUwriteColors.kSecondaryTeal,
                      PetUwriteColors.kSecondaryTeal.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: PetUwriteColors.kSecondaryTeal.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
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
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Continue to Checkout',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
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

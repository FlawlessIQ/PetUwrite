import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../theme/clovara_theme.dart';
import '../models/risk_score.dart';
import '../models/pet.dart';
import 'plan_selection_screen.dart';
import 'medical_underwriting_screen.dart';

/// AI Analysis Screen - Shows animated risk analysis
/// Displays: risk calculation progress, score gauge, AI insights, recommendations
class AIAnalysisScreen extends StatefulWidget {
  final Pet pet;
  final RiskScore riskScore;
  final Map<String, dynamic> routeArguments;

  const AIAnalysisScreen({
    super.key,
    required this.pet,
    required this.riskScore,
    required this.routeArguments,
  });

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _stepKeys = <GlobalKey>[];
  final GlobalKey _scoreGaugeKey = GlobalKey();
  final GlobalKey _categoryScoresKey = GlobalKey();
  final GlobalKey _riskFactorsKey = GlobalKey();
  final GlobalKey _aiInsightsKey = GlobalKey();

  bool _userScrolling = false;
  Timer? _resumeAutoScrollTimer;

  int _currentStep = 0;
  final List<AnalysisStep> _steps = [];

  @override
  void initState() {
    super.initState();

    // Initialize steps based on risk score
    _steps.addAll([
      AnalysisStep(
        icon: Icons.pets,
        title: 'Analyzing ${widget.pet.name}\'s profile',
        description: '${widget.pet.breed} • ${widget.pet.ageInYears} years old',
      ),
      AnalysisStep(
        icon: Icons.health_and_safety,
        title: 'Evaluating health factors',
        description: 'Age, breed, pre-existing conditions',
      ),
      AnalysisStep(
        icon: Icons.location_on,
        title: 'Checking regional factors',
        description: 'Veterinary costs and climate risks',
      ),
      AnalysisStep(
        icon: Icons.auto_awesome,
        title: 'Running AI analysis',
        description: 'AI-powered risk assessment',
      ),
      AnalysisStep(
        icon: Icons.calculate,
        title: 'Calculating risk score',
        description: 'Personalizing your coverage',
      ),
    ]);

    // Keys for auto-scrolling to each step.
    _stepKeys.addAll(List.generate(_steps.length, (_) => GlobalKey()));

    // Main animation controller for step progression
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );

    // Score reveal animation
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scoreAnimation =
        Tween<double>(begin: 0.0, end: widget.riskScore.overallScore).animate(
          CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
        );

    _startAnalysis();
  }

  void _onUserScrollActivity() {
    _userScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      _userScrolling = false;
    });
  }

  void _autoScrollTo(GlobalKey key, {double alignment = 0.15}) {
    if (!mounted || _userScrolling) return;
    final ctx = key.currentContext;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userScrolling) return;
      final ctx2 = key.currentContext;
      if (ctx2 == null) return;
      Scrollable.ensureVisible(
        ctx2,
        alignment: alignment,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startAnalysis() async {
    // Animate through each step
    for (int i = 0; i < _steps.length; i++) {
      if (mounted) {
        setState(() => _currentStep = i);
        // Follow progress down the screen.
        if (i >= 0 && i < _stepKeys.length) {
          _autoScrollTo(_stepKeys[i]);
        }
        await Future.delayed(const Duration(milliseconds: 1600));
      }
    }

    // Start score animation
    if (mounted) {
      // When insights become visible, scroll to the score section.
      _autoScrollTo(_scoreGaugeKey, alignment: 0.08);
      _scoreController.forward();
      // Wait longer to allow user to see insights
      await Future.delayed(const Duration(milliseconds: 4000));

      // Route through medical underwriting when we need additional disclosures/questions.
      final hasPreExistingConditions =
          widget.pet.preExistingConditions.isNotEmpty &&
          widget.pet.preExistingConditions.any(
            (condition) => condition != 'None' && condition.isNotEmpty,
          );
      final hasRuleExclusions =
          widget.routeArguments['hasExclusions'] == true ||
          (widget.routeArguments['excludedConditions'] is List &&
              (widget.routeArguments['excludedConditions'] as List).isNotEmpty);
      final needsMedicalUnderwriting =
          widget.routeArguments['needsMedicalUnderwriting'] == true;

      final requiresUnderwriting =
          hasPreExistingConditions ||
          hasRuleExclusions ||
          needsMedicalUnderwriting;

      print(
        '🧭 Underwriting routing: requires=$requiresUnderwriting preExisting=$hasPreExistingConditions hasRuleExclusions=$hasRuleExclusions needsMedicalUnderwriting=$needsMedicalUnderwriting conditions=${widget.pet.preExistingConditions.isEmpty ? '(none)' : widget.pet.preExistingConditions.join(', ')}',
      );

      // Navigate to appropriate screen
      if (mounted) {
        if (requiresUnderwriting) {
          // Route through medical underwriting for detailed history collection
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MedicalUnderwritingScreen(
                pet: widget.pet,
                riskScore: widget.riskScore,
                quoteData: widget.routeArguments,
              ),
            ),
          );
        } else {
          // Skip underwriting for healthy pets
          final nextArgs = <String, dynamic>{
            ...widget.routeArguments,
            'pricingEnabled': true,
            'underwritingStatus': 'APPROVED',
              'underwritingReason': 'NO_DISCLOSED_CONDITIONS',
              'integrityPassed': true,
          };
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PlanSelectionScreen(),
              settings: RouteSettings(arguments: nextArgs),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _scoreController.dispose();
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showInsights = _currentStep >= _steps.length - 1;

    return Scaffold(
      backgroundColor: ClovaraColors.forest,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification ||
                notification is ScrollStartNotification) {
              _onUserScrollActivity();
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Agent avatar
                  _buildAvatar(),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    showInsights ? 'Analysis Complete' : 'Analyzing Coverage',
                    style: ClovaraTypography.h2.copyWith(color: Colors.white),
                  ),

                  const SizedBox(height: 48),

                  // Analysis steps
                  ...List.generate(
                    _steps.length,
                    (index) => _buildStepCard(index),
                  ),

                  const SizedBox(height: 32),

                  // Risk score gauge (shown after steps complete)
                  if (showInsights)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        children: [
                          KeyedSubtree(key: _scoreGaugeKey, child: _buildScoreGauge()),
                          const SizedBox(height: 32),
                          KeyedSubtree(
                            key: _categoryScoresKey,
                            child: _buildCategoryScores(),
                          ),
                          const SizedBox(height: 24),
                          KeyedSubtree(
                            key: _riskFactorsKey,
                            child: _buildRiskFactors(),
                          ),
                          const SizedBox(height: 24),
                          if (widget.riskScore.aiAnalysis != null)
                            KeyedSubtree(
                              key: _aiInsightsKey,
                              child: _buildAIInsights(),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ClovaraColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
    );
  }

  Widget _buildStepCard(int index) {
    final step = _steps[index];
    final isActive = index == _currentStep;
    final isComplete = index < _currentStep;

    return KeyedSubtree(
      key: index >= 0 && index < _stepKeys.length ? _stepKeys[index] : null,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0), // Clamp opacity to valid range
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isActive || isComplete
                ? ClovaraColors.brandGradientSoft
                : null,
            color: isActive || isComplete
                ? null
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? ClovaraColors.clover
                  : isComplete
                  ? ClovaraColors.kSuccessMint
                  : Colors.white.withOpacity(0.1),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isComplete
                      ? ClovaraColors.kSuccessMint
                      : isActive
                      ? ClovaraColors.clover
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: isComplete
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : isActive
                    ? TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: value * 2 * math.pi,
                            child: Icon(
                              step.icon,
                              color: ClovaraColors.forest,
                              size: 24,
                            ),
                          );
                        },
                      )
                    : Icon(
                        step.icon,
                        color: Colors.white.withOpacity(0.3),
                        size: 24,
                      ),
              ),

              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: ClovaraTypography.h3.copyWith(
                        color: isActive || isComplete
                            ? ClovaraColors.forest
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: ClovaraTypography.body.copyWith(
                        color: isActive || isComplete
                            ? ClovaraColors.forest.withOpacity(0.7)
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Loading indicator for active step
              if (isActive)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(ClovaraColors.forest),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreGauge() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: ClovaraColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Risk Score',
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          // Circular score gauge
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: _scoreAnimation.value / 100,
                      strokeWidth: 12,
                      backgroundColor: ClovaraColors.forest.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        _getScoreColor(_scoreAnimation.value),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _scoreAnimation.value.toInt().toString(),
                        style: ClovaraTypography.h1.copyWith(
                          color: ClovaraColors.forest,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/100',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Risk level label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _getScoreColor(widget.riskScore.overallScore),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRiskLevelText(widget.riskScore.riskLevel),
              style: ClovaraTypography.button.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Generating personalized plans...',
            style: ClovaraTypography.body.copyWith(
              color: ClovaraColors.forest.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score < 30) return ClovaraColors.kSuccessMint;
    if (score < 60) return ClovaraColors.clover;
    if (score < 80) return ClovaraColors.kWarning;
    return ClovaraColors.kWarmCoral;
  }

  String _getRiskLevelText(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
      case RiskLevel.veryHigh:
        return 'VERY HIGH RISK';
    }
  }

  Widget _buildCategoryScores() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ClovaraColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: ClovaraColors.clover, size: 28),
              const SizedBox(width: 12),
              Text(
                'Risk Categories',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...widget.riskScore.categoryScores.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatCategoryName(entry.key),
                        style: ClovaraTypography.h3.copyWith(
                          color: ClovaraColors.forest,
                        ),
                      ),
                      Text(
                        '${entry.value.toInt()}/100',
                        style: ClovaraTypography.h3.copyWith(
                          color: _getScoreColor(entry.value),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: entry.value / 100,
                      minHeight: 12,
                      backgroundColor: ClovaraColors.forest.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                        _getScoreColor(entry.value),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRiskFactors() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ClovaraColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: ClovaraColors.kWarning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Risk Factors',
                style: ClovaraTypography.h3.copyWith(
                  color: ClovaraColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...widget.riskScore.riskFactors.map((factor) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getSeverityColor(factor.severity),
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getCategoryIcon(factor.category),
                    color: _getSeverityColor(factor.severity),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCategoryName(factor.category),
                          style: ClovaraTypography.h3.copyWith(
                            color: ClovaraColors.forest,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          factor.description,
                          style: ClovaraTypography.body.copyWith(
                            color: ClovaraColors.forest.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(factor.severity),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      factor.impact > 0
                          ? '+${factor.impact.toInt()}'
                          : '${factor.impact.toInt()}',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAIInsights() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClovaraColors.clover.withOpacity(0.2),
            ClovaraColors.sunset.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClovaraColors.clover.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: ClovaraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Insights',
                style: ClovaraTypography.h3.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.riskScore.aiAnalysis ?? 'No AI insights available',
            style: ClovaraTypography.body.copyWith(
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'age':
        return Icons.cake;
      case 'breed':
        return Icons.pets;
      case 'preexisting':
      case 'pre_existing':
        return Icons.medical_services;
      case 'medical':
      case 'medical_history':
        return Icons.local_hospital;
      case 'lifestyle':
        return Icons.directions_run;
      case 'location':
      case 'regional':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }

  Color _getSeverityColor(dynamic severity) {
    final severityStr = severity.toString().toLowerCase();
    if (severityStr.contains('low')) return ClovaraColors.kSuccessMint;
    if (severityStr.contains('medium')) return ClovaraColors.kWarning;
    return ClovaraColors.kWarmCoral;
  }
}

/// Data model for analysis steps
class AnalysisStep {
  final IconData icon;
  final String title;
  final String description;

  AnalysisStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

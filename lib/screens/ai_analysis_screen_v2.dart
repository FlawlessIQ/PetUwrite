import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/petuwrite_theme.dart';
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

class _AIAnalysisScreenState extends State<AIAnalysisScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  
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
        description: 'GPT-4o powered risk assessment',
      ),
      AnalysisStep(
        icon: Icons.calculate,
        title: 'Calculating risk score',
        description: 'Personalizing your coverage',
      ),
    ]);
    
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
    
    _scoreAnimation = Tween<double>(begin: 0.0, end: widget.riskScore.overallScore).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    
    _startAnalysis();
  }

  void _startAnalysis() async {
    // Animate through each step
    for (int i = 0; i < _steps.length; i++) {
      if (mounted) {
        setState(() => _currentStep = i);
        await Future.delayed(const Duration(milliseconds: 1600));
      }
    }
    
    // Start score animation
    if (mounted) {
      _scoreController.forward();
      // Wait longer to allow user to see insights
      await Future.delayed(const Duration(milliseconds: 4000));
      
      // Check if pet has pre-existing conditions requiring detailed underwriting
      final hasPreExistingConditions = widget.pet.preExistingConditions.isNotEmpty &&
          widget.pet.preExistingConditions.any((condition) => 
              condition != 'None' && condition.isNotEmpty);
      
      // Navigate to appropriate screen
      if (mounted) {
        if (hasPreExistingConditions) {
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PlanSelectionScreen(),
              settings: RouteSettings(arguments: widget.routeArguments),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showInsights = _currentStep >= _steps.length - 1;
    
    return Scaffold(
      backgroundColor: PetUwriteColors.kPrimaryNavy,
      body: SafeArea(
        child: SingleChildScrollView(
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
                  style: PetUwriteTypography.h2.copyWith(color: Colors.white),
                ),
                
                const SizedBox(height: 48),
                
                // Analysis steps
                ...List.generate(_steps.length, (index) => _buildStepCard(index)),
                
                const SizedBox(height: 32),
                
                // Risk score gauge (shown after steps complete)
                if (showInsights)
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      children: [
                        _buildScoreGauge(),
                        const SizedBox(height: 32),
                        _buildCategoryScores(),
                        const SizedBox(height: 24),
                        _buildRiskFactors(),
                        const SizedBox(height: 24),
                        if (widget.riskScore.aiAnalysis != null)
                          _buildAIInsights(),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
              ],
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
        gradient: PetUwriteColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.4),
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
    
    return TweenAnimationBuilder<double>(
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
              ? PetUwriteColors.brandGradientSoft
              : null,
          color: isActive || isComplete ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? PetUwriteColors.kSecondaryTeal
                : isComplete
                    ? PetUwriteColors.kSuccessMint
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
                    ? PetUwriteColors.kSuccessMint
                    : isActive
                        ? PetUwriteColors.kSecondaryTeal
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
                                color: PetUwriteColors.kPrimaryNavy,
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
                    style: PetUwriteTypography.h4.copyWith(
                      color: isActive || isComplete
                          ? PetUwriteColors.kPrimaryNavy
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: PetUwriteTypography.body.copyWith(
                      color: isActive || isComplete
                          ? PetUwriteColors.kPrimaryNavy.withOpacity(0.7)
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
                  valueColor: AlwaysStoppedAnimation(PetUwriteColors.kPrimaryNavy),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreGauge() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: PetUwriteColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Risk Score',
            style: PetUwriteTypography.h4.copyWith(
              color: PetUwriteColors.kPrimaryNavy,
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
                      backgroundColor: PetUwriteColors.kPrimaryNavy.withOpacity(0.2),
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
                        style: PetUwriteTypography.h1.copyWith(
                          color: PetUwriteColors.kPrimaryNavy,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/100',
                        style: PetUwriteTypography.bodyLarge.copyWith(
                          color: PetUwriteColors.kPrimaryNavy.withOpacity(0.6),
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
              style: PetUwriteTypography.button.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Generating personalized plans...',
            style: PetUwriteTypography.body.copyWith(
              color: PetUwriteColors.kPrimaryNavy.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score < 30) return PetUwriteColors.kSuccessMint;
    if (score < 60) return PetUwriteColors.kSecondaryTeal;
    if (score < 80) return PetUwriteColors.kWarning;
    return PetUwriteColors.kWarmCoral;
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
        gradient: PetUwriteColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
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
              Icon(Icons.analytics, color: PetUwriteColors.kSecondaryTeal, size: 28),
              const SizedBox(width: 12),
              Text(
                'Risk Categories',
                style: PetUwriteTypography.h3.copyWith(
                  color: PetUwriteColors.kPrimaryNavy,
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
                        style: PetUwriteTypography.h4.copyWith(
                          color: PetUwriteColors.kPrimaryNavy,
                        ),
                      ),
                      Text(
                        '${entry.value.toInt()}/100',
                        style: PetUwriteTypography.h4.copyWith(
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
                      backgroundColor: PetUwriteColors.kPrimaryNavy.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(_getScoreColor(entry.value)),
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
        gradient: PetUwriteColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
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
              Icon(Icons.warning_amber, color: PetUwriteColors.kWarning, size: 28),
              const SizedBox(width: 12),
              Text(
                'Risk Factors',
                style: PetUwriteTypography.h3.copyWith(
                  color: PetUwriteColors.kPrimaryNavy,
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
                          style: PetUwriteTypography.h4.copyWith(
                            color: PetUwriteColors.kPrimaryNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          factor.description,
                          style: PetUwriteTypography.body.copyWith(
                            color: PetUwriteColors.kPrimaryNavy.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(factor.severity),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      factor.impact > 0 ? '+${factor.impact.toInt()}' : '${factor.impact.toInt()}',
                      style: PetUwriteTypography.bodySmall.copyWith(
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
            PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
            PetUwriteColors.kAccentSky.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
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
                  gradient: PetUwriteColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Insights',
                style: PetUwriteTypography.h3.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.riskScore.aiAnalysis ?? 'No AI insights available',
            style: PetUwriteTypography.body.copyWith(
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
    if (severityStr.contains('low')) return PetUwriteColors.kSuccessMint;
    if (severityStr.contains('medium')) return PetUwriteColors.kWarning;
    return PetUwriteColors.kWarmCoral;
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

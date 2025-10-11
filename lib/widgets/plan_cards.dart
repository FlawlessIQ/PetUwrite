import 'package:flutter/material.dart';
import '../services/quote_engine.dart';

/// Widget to display insurance plan options as cards
class PlanCards extends StatefulWidget {
  final List<Plan> plans;
  final Function(Plan)? onSelectPlan;
  final Plan? selectedPlan;
  final bool showComparison;
  
  const PlanCards({
    super.key,
    required this.plans,
    this.onSelectPlan,
    this.selectedPlan,
    this.showComparison = false,
  });
  
  @override
  State<PlanCards> createState() => _PlanCardsState();
}

class _PlanCardsState extends State<PlanCards> {
  int? _hoveredIndex;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout: single column on mobile, row on tablet+
        final isMobile = constraints.maxWidth < 768;
        
        if (isMobile) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }
  
  Widget _buildMobileLayout() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.plans.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildPlanCard(widget.plans[index], index),
        );
      },
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.plans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == widget.plans.length - 1 ? 0 : 8,
            ),
            child: _buildPlanCard(plan, index),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildPlanCard(Plan plan, int index) {
    final isSelected = widget.selectedPlan == plan;
    final isHovered = _hoveredIndex == index;
    final isPlusOrElite = plan.type == PlanType.plus || plan.type == PlanType.elite;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        child: Card(
          elevation: isHovered ? 12 : (isSelected ? 8 : 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isPlusOrElite
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: plan.type == PlanType.elite
                          ? [
                              Colors.purple.shade50,
                              Colors.blue.shade50,
                            ]
                          : [
                              Colors.blue.shade50,
                              Colors.green.shade50,
                            ],
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(plan),
                _buildPricing(plan),
                _buildCoverageDetails(plan),
                _buildFeatures(plan),
                if (widget.showComparison) _buildComparisonScenarios(plan),
                _buildActionButton(plan, isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(Plan plan) {
    Color headerColor;
    IconData icon;
    
    switch (plan.type) {
      case PlanType.basic:
        headerColor = Colors.blue;
        icon = Icons.shield_outlined;
        break;
      case PlanType.plus:
        headerColor = Colors.green;
        icon = Icons.shield;
        break;
      case PlanType.elite:
        headerColor = Colors.purple;
        icon = Icons.workspace_premium;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: headerColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: headerColor),
          const SizedBox(height: 12),
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: headerColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (plan.type == PlanType.plus)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                label: const Text('MOST POPULAR'),
                backgroundColor: Colors.orange,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPricing(Plan plan) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\$',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                plan.monthlyPremium.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const Text(
            'per month',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          if (plan.multiPetDiscount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Multi-pet discount: -\$${plan.discountAmount.toStringAsFixed(2)}/mo (${(plan.multiPetDiscount * 100).toInt()}%)',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Annual: \$${plan.annualPremium.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCoverageDetails(Plan plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          _buildCoverageRow(
            'Annual Deductible',
            '\$${plan.annualDeductible.toStringAsFixed(0)}',
            Icons.attach_money,
          ),
          const SizedBox(height: 12),
          _buildCoverageRow(
            'Reimbursement',
            plan.coveragePercentage,
            Icons.pie_chart,
          ),
          const SizedBox(height: 12),
          _buildCoverageRow(
            'Annual Max',
            '\$${(plan.maxAnnualCoverage / 1000).toStringAsFixed(0)}K',
            Icons.trending_up,
          ),
          if (plan.coPayPercentage > 0) ...[
            const SizedBox(height: 12),
            _buildCoverageRow(
              'Co-pay',
              '${plan.coPayPercentage.toInt()}%',
              Icons.handshake,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCoverageRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatures(Plan plan) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s Included',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.features.take(6).map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
          if (plan.features.length > 6)
            TextButton(
              onPressed: () {
                _showAllFeatures(plan);
              },
              child: Text('+ ${plan.features.length - 6} more features'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonScenarios(Plan plan) {
    final engine = QuoteEngine();
    final scenarios = [
      ClaimScenario(description: 'Minor (\$500)', claimAmount: 500),
      ClaimScenario(description: 'Major (\$5K)', claimAmount: 5000),
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Example Claims',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...scenarios.map((scenario) {
            final outOfPocket = engine.calculateOutOfPocket(
              plan: plan,
              claimAmount: scenario.claimAmount,
            );
            final coverage = engine.calculateCoverageAmount(
              plan: plan,
              claimAmount: scenario.claimAmount,
            );
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    scenario.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'You pay: \$${outOfPocket.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'We cover: \$${coverage.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(Plan plan, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: widget.onSelectPlan != null
            ? () => widget.onSelectPlan!(plan)
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          isSelected ? 'SELECTED' : 'SELECT PLAN',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  void _showAllFeatures(Plan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plan.name} - All Features',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Included Features',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...plan.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  const Text(
                    'Exclusions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...plan.exclusions.map((exclusion) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.cancel,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                exclusion,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

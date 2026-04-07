#!/usr/bin/env python3
"""Patch plan_selection_screen.dart with premium visual updates."""

import re

path = '/Users/conorlawless/Development/Clovara/lib/screens/plan_selection_screen.dart'

with open(path) as f:
    content = f.read()

# ============================================================
# 1. UPDATE APPBAR — new header text + trust strip subtext
# ============================================================
content = content.replace(
    "        ? 'Pick coverage that fits your budget'\n"
    "        : 'For \$petName — pick coverage that fits your budget';",
    "        ? 'Choose the coverage that fits your budget'\n"
    "        : 'Coverage for \$petName that fits your budget';"
)

content = content.replace(
    "            'Choose your plan',",
    "            'Choose your coverage',",
)

# ============================================================
# 2. UPDATE STICKY CHECKOUT BAR — better CTA + daily price
# ============================================================

old_sticky = """  Widget _buildStickyCheckoutBar() {
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
                    '\\$${price.toStringAsFixed(0)}/mo',
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
  }"""

new_sticky = r"""  Widget _buildStickyCheckoutBar() {
    final plan = _plans[_selectedPlanIndex];
    final name = plan is Plan ? plan.name : (plan as PlanData).name;
    final price = plan is Plan
        ? plan.monthlyPremium
        : (plan as PlanData).monthlyPrice;
    final daily = (price / 30).toStringAsFixed(2);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
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
                    '$name plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ClovaraColors.forest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price.toStringAsFixed(0)}/mo  ≈  \$$daily/day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _continueToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClovaraColors.clover,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text(
                  'Secure my coverage',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }"""

content = content.replace(old_sticky, new_sticky)

# ============================================================
# 3. UPDATE PROGRESS HERO — new copy + trust strip
# ============================================================

old_hero = """  Widget _buildProgressHero() {
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
  }"""

new_hero = r"""  Widget _buildProgressHero() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ClovaraColors.clover.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: ClovaraColors.clover,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 2 of 3',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ClovaraColors.clover,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose your coverage',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: ClovaraColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You can adjust this anytime. No pressure.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Trust strip
        _buildTrustStrip(),
      ],
    );
  }

  Widget _buildTrustStrip() {
    const items = [
      (Icons.local_hospital_outlined, 'Any licensed vet'),
      (Icons.block_outlined, 'No networks'),
      (Icons.event_available_outlined, 'Cancel anytime'),
      (Icons.bolt_outlined, 'Digital claims'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1, size: 15, color: ClovaraColors.clover),
                  const SizedBox(width: 6),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ClovaraColors.forest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }"""

content = content.replace(old_hero, new_hero)

# ============================================================
# 4. UPDATE EXAMPLE BILLS — new title, explanatory line, cleaner
# ============================================================

content = content.replace(
    "            'Example bills',",
    "            'What this means in real life',",
)

content = content.replace(
    "            'Estimated out-of-pocket after deductible and reimbursement.',",
    "            'Without insurance, you would pay the full amount. Here\\'s what you\\'d pay with this plan.',",
)

# Also update accordion title
content = content.replace(
    "                      'Example bills',",
    "                      'What this means in real life',",
)
content = content.replace(
    "                      'See estimated out-of-pocket costs',",
    "                      'See how much you\\'d save on real vet bills',",
)

# ============================================================
# 5. UPDATE EXCLUSIONS — softer, rename
# ============================================================

content = content.replace(
    "                      'Important: coverage exclusions',",
    "                      \"What's not covered (clear and upfront)\",",
)

# Soften the exclusion styling — remove warning color
content = content.replace(
    "                        color: AppColors.warning,\n"
    "                        height: 1.2,",
    "                        color: ClovaraColors.forest,\n"
    "                        height: 1.2,",
)

# Move exclusions below overview in mobile (swap order)
content = content.replace(
    "        SliverToBoxAdapter(child: _buildExclusionsCallout()),\n"
    "        SliverToBoxAdapter(child: _buildMobilePlanCarousel()),\n"
    "        SliverToBoxAdapter(\n"
    "          child: Padding(\n"
    "            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),\n"
    "            child: _buildSelectedPlanOverview(selected, isCompact: true),\n"
    "          ),\n"
    "        ),",
    "        SliverToBoxAdapter(child: _buildMobilePlanCarousel()),\n"
    "        SliverToBoxAdapter(\n"
    "          child: Padding(\n"
    "            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),\n"
    "            child: _buildSelectedPlanOverview(selected, isCompact: true),\n"
    "          ),\n"
    "        ),\n"
    "        SliverToBoxAdapter(child: _buildExclusionsCallout()),",
)

# ============================================================
# 6. UPDATE SELECTED PLAN OVERVIEW — daily price equivalent + bigger price
# ============================================================

# Find and replace the price display in _buildSelectedPlanOverview
old_price_row = r"""          Row(
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
          ),"""

new_price_row = r"""          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: isCompact ? 38 : 52,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/month',
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '≈ \$${(price / 30).toStringAsFixed(2)}/day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ClovaraColors.clover,
                      ),
                    ),
                    if (plan is Plan)
                      Text(
                        '\$${plan.annualPremium.toStringAsFixed(0)}/year',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),"""

content = content.replace(old_price_row, new_price_row)

# ============================================================
# 7. UPDATE MOBILE PLAN CARD — better labels, scale effect
# ============================================================

# Replace "Recommended" badge with plan-type specific labels 
content = content.replace(
    """                    if (recommended)
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
                      ),""",
    """                    if (recommended || _tierBadge(plan) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: recommended ? ClovaraColors.clover : ClovaraColors.forest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recommended ? 'Recommended' : (_tierBadge(plan) ?? ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),""",
    1  # only first occurrence (mobile card)
)

# ============================================================
# 8. UPDATE DENSE PLAN CARD — same label treatment
# ============================================================

content = content.replace(
    """                        if (recommended)
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
                          ),""",
    """                        if (recommended || _tierBadge(plan) != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: recommended ? ClovaraColors.clover : ClovaraColors.forest.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              recommended ? 'Recommended' : (_tierBadge(plan) ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),"""
)

# ============================================================
# 9. ADD _tierBadge helper after _tierTagline
# ============================================================

content = content.replace(
    "  void _openComparePlans({required bool isMobile}) {",
    r"""  String? _tierBadge(dynamic plan) {
    if (plan is PlanData) {
      if (plan.isPopular) return 'Most popular';
      return null;
    }
    if (plan is! Plan) return null;
    switch (plan.type) {
      case PlanType.basic:
        return null;
      case PlanType.standard:
        return 'Most popular';
      case PlanType.plus:
        return 'Best value';
      case PlanType.premium:
        return 'Maximum protection';
      case PlanType.unlimited:
        return null;
    }
  }

  void _openComparePlans({required bool isMobile}) {"""
)

# ============================================================
# 10. UPDATE DAILY PRICE IN MOBILE CARD
# ============================================================

# Add daily price under the /mo in the mobile plan card
content = content.replace(
    """                    const Spacer(),
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
                        '\$reimburse% back • \$limitLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),""",
    r"""                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ClovaraColors.clover.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '≈ \$${(price / 30).toStringAsFixed(2)}/day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ClovaraColors.clover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$reimburse% back • $limitLabel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),"""
)

# ============================================================
# 11. UPDATE INCLUDED CARD TITLE (in _buildIncludedCard)
# ============================================================

content = content.replace(
    "            'What\\'s included',\n"
    "            style: TextStyle(",
    "            'What\\'s included in your plan',\n"
    "            style: TextStyle(",
    1  # only first occurrence
)

# Also update the desktop section label
content = content.replace(
    "                          title: 'What\\'s included',",
    "                          title: 'What\\'s included in your plan',",
)

# ============================================================
# 12. UPDATE DESKTOP RIGHT PANEL — add trust strip 
# ============================================================

content = content.replace(
    """                        _buildSectionLabel(
                          icon: Icons.shield_outlined,
                          title: 'Coverage summary',
                          subtitle:
                              'Your price and core coverage levers at a glance.',
                          accent: accent,
                        ),
                        const SizedBox(height: 10),
                        _buildSelectedPlanOverview(selected),""",
    """                        _buildSectionLabel(
                          icon: Icons.shield_outlined,
                          title: 'Coverage summary',
                          subtitle:
                              'Your price and core coverage levers at a glance.',
                          accent: accent,
                        ),
                        const SizedBox(height: 10),
                        _buildTrustStrip(),
                        const SizedBox(height: 14),
                        _buildSelectedPlanOverview(selected),"""
)

# ============================================================
# 13. UPDATE DESKTOP LEFT PANEL title
# ============================================================

content = content.replace(
    "                    'Pick a tier, then personalize coverage and add-ons.',",
    "                    'You can adjust this anytime. No pressure.',",
)

# ============================================================
# 14. DESKTOP CTA — add checkout button at bottom of right panel
# ============================================================

content = content.replace(
    "                        _buildIncludedCard(selected),\n"
    "                        const SizedBox(height: 16),\n"
    "                      ],\n"
    "                    ),\n"
    "                  ),\n"
    "                ),\n"
    "              ),\n"
    "            ],\n"
    "          ),\n"
    "        ),\n"
    "      ),\n"
    "    );\n"
    "  }\n"
    "\n"
    "  Widget _buildSectionLabel({",
    "                        _buildIncludedCard(selected),\n"
    "                        const SizedBox(height: 20),\n"
    "                        SizedBox(\n"
    "                          width: double.infinity,\n"
    "                          height: 56,\n"
    "                          child: ElevatedButton.icon(\n"
    "                            onPressed: _continueToCheckout,\n"
    "                            style: ElevatedButton.styleFrom(\n"
    "                              backgroundColor: ClovaraColors.clover,\n"
    "                              foregroundColor: Colors.white,\n"
    "                              elevation: 0,\n"
    "                              shape: RoundedRectangleBorder(\n"
    "                                borderRadius: BorderRadius.circular(16),\n"
    "                              ),\n"
    "                            ),\n"
    "                            icon: const Icon(Icons.lock_outline, size: 18),\n"
    "                            label: const Text(\n"
    "                              'Continue to secure your coverage',\n"
    "                              style: TextStyle(\n"
    "                                fontWeight: FontWeight.w900,\n"
    "                                fontSize: 15,\n"
    "                              ),\n"
    "                            ),\n"
    "                          ),\n"
    "                        ),\n"
    "                        const SizedBox(height: 16),\n"
    "                      ],\n"
    "                    ),\n"
    "                  ),\n"
    "                ),\n"
    "              ),\n"
    "            ],\n"
    "          ),\n"
    "        ),\n"
    "      ),\n"
    "    );\n"
    "  }\n"
    "\n"
    "  Widget _buildSectionLabel({",
)

# ============================================================
# 15. SOFTEN desktop right panel border → shadow only
# ============================================================

content = content.replace(
    "                  decoration: BoxDecoration(\n"
    "                    color: AppColors.surface1,\n"
    "                    borderRadius: BorderRadius.circular(22),\n"
    "                    border: Border.all(color: Colors.grey.shade200),\n"
    "                    boxShadow: AppShadows.soft,\n"
    "                  ),",
    "                  decoration: BoxDecoration(\n"
    "                    color: Colors.white,\n"
    "                    borderRadius: BorderRadius.circular(22),\n"
    "                    boxShadow: [\n"
    "                      BoxShadow(\n"
    "                        color: Colors.black.withValues(alpha: 0.05),\n"
    "                        blurRadius: 24,\n"
    "                        offset: const Offset(0, 8),\n"
    "                      ),\n"
    "                    ],\n"
    "                  ),",
)

# ============================================================
# 16. Enhance mobile plan card - stronger shadow + border for selected
# ============================================================

content = content.replace(
    "            decoration: BoxDecoration(\n"
    "              borderRadius: BorderRadius.circular(20),\n"
    "              border: Border.all(color: border, width: selected ? 2 : 1),\n"
    "              color: bg,\n"
    "              boxShadow: [\n"
    "                BoxShadow(\n"
    "                  color: Colors.black.withValues(alpha: 0.05),\n"
    "                  blurRadius: 24,\n"
    "                  offset: const Offset(0, 14),\n"
    "                ),\n"
    "              ],\n"
    "            ),",
    "            decoration: BoxDecoration(\n"
    "              borderRadius: BorderRadius.circular(20),\n"
    "              border: Border.all(color: border, width: selected ? 2.5 : 1),\n"
    "              color: bg,\n"
    "              boxShadow: [\n"
    "                BoxShadow(\n"
    "                  color: selected\n"
    "                      ? ClovaraColors.clover.withOpacity(0.12)\n"
    "                      : Colors.black.withValues(alpha: 0.05),\n"
    "                  blurRadius: selected ? 32 : 24,\n"
    "                  offset: Offset(0, selected ? 16 : 14),\n"
    "                ),\n"
    "              ],\n"
    "            ),",
)


with open(path, 'w') as f:
    f.write(content)

print(f'✅ Patched plan_selection_screen.dart ({len(content)} chars)')

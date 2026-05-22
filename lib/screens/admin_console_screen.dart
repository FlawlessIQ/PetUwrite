import 'package:flutter/material.dart';

import '../admin_console/admin_nav.dart';
import '../admin_console/admin_scaffold.dart';
import '../admin_console/pages/admin_marketing_page.dart';
import '../admin_console/pages/admin_overview_page.dart';
import '../admin/admin_product_catalog_page.dart';
import 'admin/claims_analytics_tab.dart';
import 'admin/claims_review_tab.dart';
import 'admin/benchmarking_tab.dart';
import 'admin/policies_pipeline_tab.dart';
import 'admin/underwriting_cases_tab.dart';
import 'admin_rules_editor_page.dart';
import '../widgets/system_health_widget.dart';

/// Enterprise Admin Console entrypoint.
///
/// This replaces the old tabbed admin dashboard with a persistent left nav,
/// global top bar, and high-density operational modules.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  AdminNavItem _selected = AdminNavItem.overview;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      selected: _selected,
      onSelect: (item) => setState(() => _selected = item),
      title: 'Clovara',
      subtitle: _subtitleFor(_selected),
      body: _buildBody(),
    );
  }

  String _subtitleFor(AdminNavItem item) {
    switch (item) {
      case AdminNavItem.overview:
        return 'Automation command center';
      case AdminNavItem.marketing:
        return 'Channels, promo codes, and performance';
      case AdminNavItem.underwritingInbox:
        return 'Decision ledger, rules fired, and evidence signals';
      case AdminNavItem.claimsInbox:
        return 'Claims automation, payout status, and exceptions';
      case AdminNavItem.claimsAnalytics:
        return 'Trends, cohorts, and actionable insights';
      case AdminNavItem.benchmarking:
        return 'Benchmark Clovara vs market reference bands';
      case AdminNavItem.policies:
        return 'Policy lifecycle pipeline';
      case AdminNavItem.rulesAndPricing:
        return 'Rules, versioning, safe deploy';
      case AdminNavItem.products:
        return 'Products, riders, pricing catalog';
      case AdminNavItem.systemHealth:
        return 'Operational monitoring & reconciliation';
    }
  }

  Widget _buildBody() {
    switch (_selected) {
      case AdminNavItem.overview:
        return AdminOverviewPage(
          onOpenUnderwriting: () =>
              setState(() => _selected = AdminNavItem.underwritingInbox),
          onOpenClaims: () =>
              setState(() => _selected = AdminNavItem.claimsInbox),
          onOpenPolicies: () =>
              setState(() => _selected = AdminNavItem.policies),
          onOpenHealth: () =>
              setState(() => _selected = AdminNavItem.systemHealth),
        );

      case AdminNavItem.marketing:
        return const AdminMarketingPage();

      case AdminNavItem.underwritingInbox:
        return const UnderwritingCasesTab();

      case AdminNavItem.claimsInbox:
        return const ClaimsReviewTab();

      case AdminNavItem.claimsAnalytics:
        return ClaimsAnalyticsTab(
          onOpenInbox: () =>
              setState(() => _selected = AdminNavItem.claimsInbox),
        );

      case AdminNavItem.benchmarking:
        return const BenchmarkingTab();

      case AdminNavItem.policies:
        return const PoliciesPipelineTab();

      case AdminNavItem.rulesAndPricing:
        return const AdminRulesEditorPage();

      case AdminNavItem.products:
        return const AdminProductCatalogPage();

      case AdminNavItem.systemHealth:
        return ListView(children: const [SystemHealthWidget()]);
    }
  }
}

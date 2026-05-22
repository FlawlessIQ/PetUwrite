import 'package:flutter/material.dart';

/// Enterprise Admin Console navigation model.
///
/// Keep this as the single source of truth for all admin modules.
enum AdminNavItem {
  overview,
  marketing,
  underwritingInbox,
  claimsInbox,
  claimsAnalytics,
  benchmarking,
  policies,
  rulesAndPricing,
  products,
  systemHealth,
}

class AdminNavSpec {
  final AdminNavItem item;
  final String label;
  final IconData icon;

  const AdminNavSpec({
    required this.item,
    required this.label,
    required this.icon,
  });
}

const List<AdminNavSpec> kAdminNavItems = <AdminNavSpec>[
  AdminNavSpec(
    item: AdminNavItem.overview,
    label: 'Overview',
    icon: Icons.dashboard_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.marketing,
    label: 'Marketing',
    icon: Icons.campaign_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.underwritingInbox,
    label: 'Decision Ledger',
    icon: Icons.account_tree_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.claimsInbox,
    label: 'Claims Automation',
    icon: Icons.verified_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.claimsAnalytics,
    label: 'Claims Analytics',
    icon: Icons.query_stats_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.benchmarking,
    label: 'Benchmarking',
    icon: Icons.insights_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.policies,
    label: 'Policies',
    icon: Icons.policy_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.rulesAndPricing,
    label: 'Rules & Pricing',
    icon: Icons.tune_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.products,
    label: 'Products',
    icon: Icons.inventory_2_outlined,
  ),
  AdminNavSpec(
    item: AdminNavItem.systemHealth,
    label: 'System Health',
    icon: Icons.monitor_heart_outlined,
  ),
];

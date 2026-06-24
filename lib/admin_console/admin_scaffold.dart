import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/clovara_logo.dart';
import '../utils/marketing_site_redirect.dart';
import 'admin_nav.dart';
import 'admin_theme.dart';

class AdminScaffold extends StatelessWidget {
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;

  final String title;
  final String? subtitle;
  final List<Widget>? pageActions;
  final Widget body;

  const AdminScaffold({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.title,
    required this.body,
    this.subtitle,
    this.pageActions,
  });

  bool _isCompact(double width) => width < 980;

  ThemeData _adminTheme(BuildContext context) {
    final base = Theme.of(context);
    final colorScheme = base.colorScheme.copyWith(
      primary: AdminColors.success,
      secondary: AdminColors.warning,
      surface: AdminColors.surface,
      surfaceContainerHighest: AdminColors.surfaceMuted,
      outline: AdminColors.border,
      outlineVariant: AdminColors.border,
      onSurface: AdminColors.text,
      onSurfaceVariant: AdminColors.muted,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AdminColors.background,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.lg),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: 1,
        space: 24,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AdminColors.surfaceMuted),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminColors.successSoft;
          }
          if (states.contains(WidgetState.hovered)) {
            return AdminColors.surfaceRaised;
          }
          return AdminColors.surface;
        }),
        headingTextStyle: base.textTheme.labelSmall?.copyWith(
          color: AdminColors.text,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
        dataTextStyle: base.textTheme.bodySmall?.copyWith(
          color: AdminColors.text,
          fontWeight: FontWeight.w600,
        ),
        dividerThickness: 0.6,
        columnSpacing: 28,
        horizontalMargin: 18,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.success, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(constraints.maxWidth);

        return Theme(
          data: _adminTheme(context),
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AdminColors.surface,
              foregroundColor: AdminColors.text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 12,
              shape: const Border(
                bottom: BorderSide(color: AdminColors.border, width: 1),
              ),
              title: Row(
                children: [
                  if (compact)
                    Builder(
                      builder: (innerContext) {
                        return IconButton(
                          tooltip: 'Menu',
                          onPressed: () =>
                              Scaffold.of(innerContext).openDrawer(),
                          icon: const Icon(Icons.menu),
                        );
                      },
                    ),
                  Padding(
                    padding: EdgeInsets.only(left: compact ? 0 : 10, right: 12),
                    child: const ClovaraLogo(
                      size: ClovaraLogoSize.small,
                      showText: false,
                    ),
                  ),
                  Expanded(
                    child: _TopBarTitle(title: title, subtitle: subtitle),
                  ),
                ],
              ),
              actions: [
                if (!compact) const _AutomationLivePill(),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _GlobalSearchField(
                        onSubmitted: (query) {
                          _showGlobalSearch(context, initialQuery: query);
                        },
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => _showGlobalSearch(context),
                    icon: const Icon(Icons.search),
                  ),
                IconButton(
                  tooltip: 'Alerts',
                  onPressed: () => _showAlerts(context),
                  icon: const Icon(Icons.notifications_none_outlined),
                ),
                IconButton(
                  tooltip: 'Tasks',
                  onPressed: () => _showTasks(context),
                  icon: const Icon(Icons.checklist_rtl_outlined),
                ),
                _ProfileMenu(
                  onSignOut: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      if (!redirectToMarketingSite(path: '/')) {
                        context.go('/sign-in');
                      }
                    }
                  },
                ),
                if (pageActions != null) ...pageActions!,
                const SizedBox(width: 10),
              ],
            ),
            drawer: compact
                ? _AdminDrawer(selected: selected, onSelect: onSelect)
                : null,
            body: Row(
              children: [
                if (!compact)
                  _AdminRail(selected: selected, onSelect: onSelect),
                Expanded(
                  child: _AdminCanvas(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGlobalSearch(BuildContext context, {String initialQuery = ''}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Global Search'),
          content: SizedBox(
            width: 720,
            child: Text(
              'Global search is scaffolded for enterprise workflows.\n\n'
              'Recommended usage: paste an exact ID (policyId, claimId, decision caseId) or an exact customer email.\n'
              'Query: "$initialQuery"',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAlerts(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alerts'),
        content: const SizedBox(
          width: 520,
          child: Text(
            'This panel is intended for automation alerts: SLA breaches, payout failures, fraud flags, rule deploy errors, and vendor outages.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTasks(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasks'),
        content: const SizedBox(
          width: 520,
          child: Text(
            'This panel is intended for automation exceptions: unreadable records, conflicting information, payment failures, and reconciliation follow-ups.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _TopBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _TopBarTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.62);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: subtitleColor),
          ),
        ],
      ],
    );
  }
}

class _AutomationLivePill extends StatelessWidget {
  const _AutomationLivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.successSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminColors.success.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AdminColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'No-touch live',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCanvas extends StatelessWidget {
  final Widget child;

  const _AdminCanvas({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AdminColors.background,
        border: Border(left: BorderSide(color: AdminColors.border)),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

class _GlobalSearchField extends StatelessWidget {
  final ValueChanged<String> onSubmitted;

  const _GlobalSearchField({required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search policies, claims, cases, customers (exact ID/email)',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        hintStyle:
            (Theme.of(context).inputDecorationTheme.hintStyle ??
                    const TextStyle())
                .copyWith(color: AdminColors.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AdminColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AdminColors.success, width: 2),
        ),
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;

  const _AdminRail({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AdminColors.sidebar,
        border: const Border(right: BorderSide(color: AdminColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AdminRadii.lg),
                border: Border.all(color: AdminColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminColors.successSoft,
                      borderRadius: BorderRadius.circular(AdminRadii.md),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: AdminColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AdminColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'No-touch command center',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AdminColors.sidebarMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              children: [
                for (final spec in kAdminNavItems)
                  _AdminNavTile(
                    spec: spec,
                    selected: spec.item == selected,
                    onTap: () => onSelect(spec.item),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: _RailHealthCard(),
          ),
        ],
      ),
    );
  }
}

class _RailHealthCard extends StatelessWidget {
  const _RailHealthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AdminColors.successSoft,
                  borderRadius: BorderRadius.circular(AdminRadii.md),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  color: AdminColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'No-touch target',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'All exception surfaces keep the customer self-serve first.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AdminColors.sidebarMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;

  const _AdminDrawer({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final themed = Theme.of(context).copyWith(
      canvasColor: AdminColors.sidebar,
      dividerColor: AdminColors.border,
      listTileTheme: const ListTileThemeData(
        iconColor: AdminColors.text,
        textColor: AdminColors.text,
      ),
    );

    return Theme(
      data: themed,
      child: Drawer(
        backgroundColor: AdminColors.sidebar,
        child: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AdminColors.sidebar),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AdminColors.border),
                Expanded(
                  child: ListView(
                    children: [
                      for (final spec in kAdminNavItems)
                        ListTile(
                          leading: Icon(
                            spec.icon,
                            color: spec.item == selected
                                ? AdminColors.success
                                : AdminColors.sidebarMuted,
                          ),
                          title: Text(
                            spec.label,
                            style: TextStyle(
                              color: spec.item == selected
                                  ? AdminColors.text
                                  : AdminColors.sidebarMuted,
                              fontWeight: spec.item == selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                          selected: spec.item == selected,
                          selectedTileColor: AdminColors.sidebarActive,
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(spec.item);
                          },
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
}

class _AdminNavTile extends StatelessWidget {
  final AdminNavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _AdminNavTile({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected ? AdminColors.text : AdminColors.sidebarMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(AdminRadii.lg),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AdminColors.sidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.lg),
          border: Border.all(
            color: selected ? AdminColors.border : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? AdminColors.successSoft
                    : AdminColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AdminRadii.md),
                border: Border.all(
                  color: selected ? AdminColors.success : AdminColors.border,
                ),
              ),
              child: Icon(
                spec.icon,
                color: selected
                    ? AdminColors.success
                    : AdminColors.sidebarMuted,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                spec.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AdminColors.success,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final Future<void> Function() onSignOut;

  const _ProfileMenu({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Admin';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) async {
        if (value == 'signout') {
          await onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'Operations User',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }
}

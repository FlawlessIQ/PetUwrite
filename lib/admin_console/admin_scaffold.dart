import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/clovara_theme.dart';
import 'admin_nav.dart';

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

  LinearGradient _navGradient() {
    final top = Color.lerp(ClovaraColors.forest, Colors.white, 0.10)!;
    final bottom = Color.lerp(ClovaraColors.forest, Colors.black, 0.04)!;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [top, bottom],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(constraints.maxWidth);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(gradient: _navGradient()),
              child: const SizedBox.expand(),
            ),
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 12,
            title: Row(
              children: [
                if (compact)
                  Builder(
                    builder: (innerContext) {
                      return IconButton(
                        tooltip: 'Menu',
                        onPressed: () => Scaffold.of(innerContext).openDrawer(),
                        icon: const Icon(Icons.menu),
                      );
                    },
                  ),
                Padding(
                  padding: EdgeInsets.only(left: compact ? 0 : 6, right: 12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: SvgPicture.asset(
                      'assets/images/clovara_mark_refined.svg',
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
                Expanded(
                  child: _TopBarTitle(title: title, subtitle: subtitle, inverse: true),
                ),
              ],
            ),
            actions: [
              if (!compact)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _GlobalSearchField(
                      dark: true,
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
              _ProfileMenu(onSignOut: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/auth-gate', (route) => false);
                }
              }),
              if (pageActions != null) ...pageActions!,
              const SizedBox(width: 8),
            ],
          ),
          drawer: compact ? _AdminDrawer(selected: selected, onSelect: onSelect) : null,
          body: Row(
            children: [
              if (!compact)
                _AdminRail(
                  selected: selected,
                  onSelect: onSelect,
                ),
              Expanded(
                child: Container(
                  color: ClovaraColors.mist,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: body,
                  ),
                ),
              ),
            ],
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
              'Recommended usage: paste an exact ID (policyId, claimId, underwriting caseId) or an exact customer email.\n'
              'Query: "$initialQuery"',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
            'This panel is intended for operational alerts: SLA breaches, payout failures, fraud flags, rule deploy errors.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
            'This panel is intended for work queues: assigned underwriting cases, claim reviews, reconciliation follow-ups.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _TopBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool inverse;

  const _TopBarTitle({
    required this.title,
    required this.subtitle,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = inverse ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final subtitleColor = inverse
        ? Colors.white.withOpacity(0.74)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.62);

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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor),
          ),
        ],
      ],
    );
  }
}

class _GlobalSearchField extends StatelessWidget {
  final ValueChanged<String> onSubmitted;
  final bool dark;

  const _GlobalSearchField({required this.onSubmitted, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search policies, claims, cases, customers (exact ID/email)',
        prefixIcon: Icon(
          Icons.search,
          color: dark ? Colors.white.withOpacity(0.86) : null,
        ),
        isDense: true,
        filled: true,
        fillColor: dark ? Colors.white.withOpacity(0.16) : Colors.white,
        hintStyle: (Theme.of(context).inputDecorationTheme.hintStyle ?? const TextStyle()).copyWith(
          color: dark ? Colors.white.withOpacity(0.72) : null,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? Colors.white.withOpacity(0.22) : ClovaraColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? ClovaraColors.clover.withOpacity(0.85) : ClovaraColors.clover,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;

  const _AdminRail({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(ClovaraColors.forest, Colors.white, 0.10)!,
            Color.lerp(ClovaraColors.forest, Colors.black, 0.04)!,
          ],
        ),
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.16)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
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
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;

  const _AdminDrawer({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final themed = Theme.of(context).copyWith(
      canvasColor: Colors.transparent,
      dividerColor: Colors.white.withOpacity(0.14),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white, textColor: Colors.white),
    );

    return Theme(
      data: themed,
      child: Drawer(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(ClovaraColors.forest, Colors.white, 0.10)!,
                  Color.lerp(ClovaraColors.forest, Colors.black, 0.04)!,
                ],
              ),
            ),
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
                Divider(height: 1, color: Colors.white.withOpacity(0.14)),
                Expanded(
                  child: ListView(
                    children: [
                      for (final spec in kAdminNavItems)
                        ListTile(
                          leading: Icon(
                            spec.icon,
                            color: Colors.white.withOpacity(spec.item == selected ? 1.0 : 0.78),
                          ),
                          title: Text(
                            spec.label,
                            style: TextStyle(
                              color: Colors.white.withOpacity(spec.item == selected ? 1.0 : 0.82),
                              fontWeight: spec.item == selected ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                          selected: spec.item == selected,
                          selectedTileColor: Colors.white.withOpacity(0.12),
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
    final c = selected ? Colors.white : Colors.white.withOpacity(0.80);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.16) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(spec.icon, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                spec.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'clovara_logo.dart';
import 'max_width.dart';

class AppTopNav extends StatelessWidget {
  const AppTopNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: MaxWidth(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: 72,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 960;
                  return Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/'),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: ClovaraLogo(
                            size: ClovaraLogoSize.medium,
                            showText: true,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!compact) ...[
                        _NavLink(label: 'Coverage', path: '/coverage'),
                        _NavLink(label: 'How it works', path: '/how-it-works'),
                        _NavLink(label: 'Resources', path: '/learn'),
                        _NavLink(label: 'FAQ', path: '/faq'),
                        _NavLink(label: 'Contact', path: '/contact'),
                        const SizedBox(width: 14),
                        SecondaryButton(
                          label: 'Sign in',
                          onPressed: () => context.go('/sign-in'),
                        ),
                        const SizedBox(width: 10),
                        PrimaryButton(
                          label: 'Get a quote',
                          icon: Icons.favorite_border_rounded,
                          onPressed: () => context.go('/quote'),
                        ),
                      ] else ...[
                        IconButton(
                          tooltip: 'Menu',
                          onPressed: () => _openMenu(context),
                          icon: const Icon(Icons.menu),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Explore Clovara',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: AppColors.deepGreen,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                _SheetLink(label: 'Coverage', path: '/coverage'),
                _SheetLink(label: 'How it works', path: '/how-it-works'),
                _SheetLink(label: 'Resources', path: '/learn'),
                _SheetLink(label: 'FAQ', path: '/faq'),
                _SheetLink(label: 'Contact', path: '/contact'),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Sign in',
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/sign-in');
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Get a quote',
                  icon: Icons.favorite_border_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/quote');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({required this.label, required this.path});

  final String label;
  final String path;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = GoRouterState.of(context).uri.path == widget.path;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: () => context.go(widget.path),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              color: selected || _hover
                  ? AppColors.deepGreen
                  : AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _SheetLink extends StatelessWidget {
  const _SheetLink({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
  }
}

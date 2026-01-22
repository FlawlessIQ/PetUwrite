import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'max_width.dart';

class AppTopNav extends StatelessWidget {
  const AppTopNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.offWhite,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: MaxWidth(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: 64,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  return Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/'),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/clovara_mark_refined.svg',
                                height: 26,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.deepGreen,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Clovara',
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      color: AppColors.deepGreen,
                                      fontSize: 18,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!compact) ...[
                        _NavLink(label: 'Coverage', path: '/coverage'),
                        _NavLink(label: 'How it works', path: '/how-it-works'),
                        _NavLink(label: 'Learn', path: '/learn'),
                        _NavLink(label: 'FAQ', path: '/faq'),
                        const SizedBox(width: 12),
                        SecondaryButton(
                          label: 'Sign in',
                          onPressed: () => context.go('/sign-in'),
                        ),
                        const SizedBox(width: 10),
                        PrimaryButton(
                          label: 'Get a quote',
                          icon: Icons.pets,
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
      backgroundColor: AppColors.surface,
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
                  'Explore',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: AppColors.deepGreen,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                _SheetLink(label: 'Coverage', path: '/coverage'),
                _SheetLink(label: 'How it works', path: '/how-it-works'),
                _SheetLink(label: 'Learn', path: '/learn'),
                _SheetLink(label: 'FAQ', path: '/faq'),
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
                  icon: Icons.pets,
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: selected || _hover
                  ? AppColors.deepGreen
                  : AppColors.textMuted,
              decoration: _hover
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationThickness: 2,
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

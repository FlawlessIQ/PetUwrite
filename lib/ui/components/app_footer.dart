import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import 'clovara_logo.dart';
import 'max_width.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 900;
                    final brandBlock = ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ClovaraLogo(
                            size: ClovaraLogoSize.small,
                            showText: true,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Pet insurance built to feel clear before you buy and supportive when your pet needs care.',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _FooterBadge(label: 'Any licensed vet'),
                              _FooterBadge(label: 'Digital claims'),
                              _FooterBadge(label: 'Clear coverage'),
                            ],
                          ),
                        ],
                      ),
                    );

                    final cols = [
                      _FooterColumn(
                        title: 'Product',
                        links: [
                          _FooterLink('Coverage', '/coverage'),
                          _FooterLink('How it works', '/how-it-works'),
                          _FooterLink('FAQ', '/faq'),
                        ],
                      ),
                      _FooterColumn(
                        title: 'Resources',
                        links: [
                          _FooterLink('Education hub', '/learn'),
                          _FooterLink('Claims basics', '/learn/claims-basics'),
                          _FooterLink(
                            'Pre-existing conditions',
                            '/learn/pre-existing-conditions',
                          ),
                        ],
                      ),
                      _FooterColumn(
                        title: 'Company',
                        links: [
                          _FooterLink('Contact', '/contact'),
                          _FooterLink('Privacy', '/privacy'),
                          _FooterLink('Terms', '/terms'),
                        ],
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          brandBlock,
                          const SizedBox(height: 24),
                          for (int i = 0; i < cols.length; i++) ...[
                            cols[i],
                            if (i != cols.length - 1)
                              const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: brandBlock),
                        const SizedBox(width: 28),
                        for (int i = 0; i < cols.length; i++) ...[
                          Expanded(child: cols[i]),
                          if (i != cols.length - 1) const SizedBox(width: 18),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 560;
                    final legalText = Text(
                      '© ${_year()} Clovara. Insurance coverage is subject to underwriting, policy terms, exclusions, state availability, and waiting periods.',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    );

                    final links = Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FooterInlineLink(
                          label: 'Privacy',
                          onTap: () => context.go('/privacy'),
                        ),
                        _FooterInlineLink(
                          label: 'Terms',
                          onTap: () => context.go('/terms'),
                        ),
                        _FooterInlineLink(
                          label: 'Contact',
                          onTap: () => context.go('/contact'),
                        ),
                      ],
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          legalText,
                          const SizedBox(height: 12),
                          links,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: legalText),
                        const SizedBox(width: 12),
                        links,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _year() => DateTime.now().year;
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final link in links) ...[
          _FooterTextLink(
            label: link.label,
            onTap: () => context.go(link.path),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _FooterTextLink extends StatefulWidget {
  const _FooterTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_FooterTextLink> createState() => _FooterTextLinkState();
}

class _FooterTextLinkState extends State<_FooterTextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowHoverHighlight: (value) => setState(() => _hover = value),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: _hover ? AppColors.deepGreen : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _FooterLink {
  _FooterLink(this.label, this.path);

  final String label;
  final String path;
}

class _FooterBadge extends StatelessWidget {
  const _FooterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FooterInlineLink extends StatelessWidget {
  const _FooterInlineLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

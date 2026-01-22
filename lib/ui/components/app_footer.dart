import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'max_width.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 760;
                  final cols = [
                    _FooterColumn(
                      title: 'Product',
                      links: [
                        _FooterLink('Coverage', '/coverage'),
                        _FooterLink('How it works', '/how-it-works'),
                        _FooterLink('FAQ', '/faq'),
                      ],
                      compact: narrow,
                    ),
                    _FooterColumn(
                      title: 'Learn',
                      links: [
                        _FooterLink('Education hub', '/learn'),
                        _FooterLink('Claims basics', '/learn/claims-basics'),
                        _FooterLink(
                          'Pre-existing conditions',
                          '/learn/pre-existing-conditions',
                        ),
                      ],
                      compact: narrow,
                    ),
                    _FooterColumn(
                      title: 'Account',
                      links: [
                        _FooterLink('Sign in', '/sign-in'),
                        _FooterLink('Get a quote', '/quote'),
                      ],
                      compact: narrow,
                    ),
                    _FooterColumn(
                      title: 'Company',
                      links: [
                        _FooterLink('Support', '/faq'),
                        _FooterLink('Contact', '/faq'),
                      ],
                      compact: narrow,
                    ),
                  ];

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < cols.length; i++) ...[
                          cols[i],
                          if (i != cols.length - 1) const SizedBox(height: 14),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cols[0]),
                      const SizedBox(width: 18),
                      Expanded(child: cols[1]),
                      const SizedBox(width: 18),
                      Expanded(child: cols[2]),
                      const SizedBox(width: 18),
                      Expanded(child: cols[3]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const Divider(height: 1),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 560;
                  final legalText = Text(
                    '© ${_year()} Clovara. Pet insurance plans are underwritten by licensed carriers. Coverage is subject to policy terms and waiting periods.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textSubtle,
                      height: 1.35,
                    ),
                  );

                  final links = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextLink(
                        label: 'Privacy',
                        onTap: () =>
                            _toast(context, 'Privacy policy coming soon.'),
                      ),
                      const SizedBox(width: 6),
                      TextLink(
                        label: 'Terms',
                        onTap: () => _toast(context, 'Terms coming soon.'),
                      ),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [legalText, const SizedBox(height: 10), links],
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
    );
  }

  static int _year() => DateTime.now().year;

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({
    required this.title,
    required this.links,
    required this.compact,
  });
  final String title;
  final List<_FooterLink> links;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleSmall!.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
          )
        : Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        SizedBox(height: compact ? 8 : 10),
        for (final l in links) ...[
          _FooterTextLink(
            label: l.label,
            onTap: () => context.go(l.path),
            compact: compact,
          ),
          SizedBox(height: compact ? 2 : 4),
        ],
      ],
    );
  }
}

class _FooterTextLink extends StatefulWidget {
  const _FooterTextLink({
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_FooterTextLink> createState() => _FooterTextLinkState();
}

class _FooterTextLinkState extends State<_FooterTextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final style =
        (widget.compact
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium)!
            .copyWith(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w600,
              decoration: _hover
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationThickness: 2,
            );

    return FocusableActionDetector(
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: widget.compact ? 4 : 6,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: style,
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

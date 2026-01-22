import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/accordion.dart';
import '../ui/components/article_tile.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/hero_stage.dart';
import '../ui/components/buttons.dart';
import '../ui/components/info/checklist_panel.dart';
import '../ui/components/info/notice_banner.dart';
import '../ui/components/image_slot.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_break.dart';
import '../ui/components/section.dart';
import '../ui/helpers/responsive_grid.dart';
import '../ui/tokens.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({super.key, required this.slug});

  final String slug;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final Map<String, GlobalKey> _anchors;

  static const _anchorIds = <String, String>{
    'summary': 'Quick summary',
    'terms': 'Key terms',
    'checklist': 'Checklist',
    'faq': 'FAQs',
  };

  @override
  void initState() {
    super.initState();
    _anchors = {for (final id in _anchorIds.keys) id: GlobalKey()};
  }

  void _scrollTo(String id) {
    final context = _anchors[id]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = _articleFromSlug(widget.slug);
    final title = article.title;

    return Column(
      children: [
        Section(
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroStage(
                  left: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall!.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          article.excerpt,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetaChip(
                              icon: Icons.bookmark_border,
                              label: article.category,
                            ),
                            _MetaChip(
                              icon: Icons.schedule,
                              label: article.readTime,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SecondaryButton(
                              label: 'Back to Learn',
                              icon: Icons.arrow_back,
                              onPressed: () => context.go('/learn'),
                            ),
                            PrimaryButton(
                              label: 'Get a quote',
                              icon: Icons.pets,
                              onPressed: () => context.go('/quote'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  right: ClipRRect(
                    borderRadius: AppRadii.br24,
                    child: Container(
                      color: AppColors.surface,
                      child: AspectRatio(
                        aspectRatio: 1.24,
                        child: article.heroImageAsset == null
                            ? ImageSlot.hero(label: 'Article header image')
                            : Image.asset(
                                article.heroImageAsset!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;

                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Anchor(
                      key: _anchors['summary'],
                      child: _ArticleSection(
                        title: 'Quick summary',
                        subtitle: 'A calm overview you can use in 60 seconds.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NoticeBanner(
                              tone: NoticeTone.neutral,
                              title: 'The simple model',
                              body:
                                  'You pay the vet upfront, then submit a claim for reimbursement based on your plan settings and policy terms.',
                              icon: Icons.info_outline,
                            ),
                            const SizedBox(height: 12),
                            const NoticeBanner(
                              tone: NoticeTone.info,
                              title: 'What changes your out-of-pocket cost',
                              body:
                                  'Deductible, reimbursement %, annual limit, and what your policy considers eligible (e.g., pre-existing conditions are excluded).',
                              icon: Icons.tune,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Anchor(
                      key: _anchors['terms'],
                      child: _ArticleSection(
                        title: 'Key terms',
                        subtitle: 'Definitions without the fine-print vibe.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DefinitionCard(
                              term: 'Deductible',
                              meaning:
                                  'The amount you pay before reimbursement begins (typically per policy period).',
                            ),
                            const SizedBox(height: 10),
                            _DefinitionCard(
                              term: 'Reimbursement %',
                              meaning:
                                  'The percentage of eligible expenses your plan reimburses after deductible.',
                            ),
                            const SizedBox(height: 10),
                            _DefinitionCard(
                              term: 'Annual limit',
                              meaning:
                                  'The maximum amount your plan will reimburse in a policy year.',
                            ),
                            const SizedBox(height: 10),
                            _DefinitionCard(
                              term: 'Pre-existing condition',
                              meaning:
                                  'A condition that showed signs or symptoms before coverage began (or during waiting periods).',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Anchor(
                      key: _anchors['checklist'],
                      child: _ArticleSection(
                        title: 'Checklist',
                        subtitle:
                            'Use this while comparing plans or preparing a claim.',
                        child: ChecklistPanel(
                          title: 'Compare with confidence',
                          items: const [
                            ChecklistItem(
                              icon: Icons.fact_check_outlined,
                              title: 'Scan exclusions first',
                              body:
                                  'Pre-existing conditions and waiting periods are usually the biggest “surprise” items.',
                            ),
                            ChecklistItem(
                              icon: Icons.receipt_long_outlined,
                              title: 'Ask for itemized invoices',
                              body:
                                  'The cleaner the invoice, the less back-and-forth during review.',
                            ),
                            ChecklistItem(
                              icon: Icons.folder_open_outlined,
                              title: 'Keep medical notes handy',
                              body:
                                  'Especially for first claims—history helps clarify what’s pre-existing.',
                            ),
                            ChecklistItem(
                              icon: Icons.payments_outlined,
                              title: 'Know what “eligible” means',
                              body:
                                  'Reimbursement is based on eligible expenses, not always the full invoice total.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Anchor(
                      key: _anchors['faq'],
                      child: _ArticleSection(
                        title: 'FAQs',
                        subtitle: 'The common “wait, but…” questions.',
                        child: Accordion(
                          items: [
                            AccordionItem(
                              question: 'Do I have to use a specific vet?',
                              answer:
                                  'Typically no—most pet insurance works with any licensed vet. You pay the vet directly, then submit a claim.',
                            ),
                            AccordionItem(
                              question: 'Why can a claim take time to review?',
                              answer:
                                  'Review may require itemized invoices, medical notes, and prior history to determine eligibility and pre-existing status.',
                            ),
                            AccordionItem(
                              question: 'Is routine wellness covered?',
                              answer:
                                  'Wellness coverage is usually optional and varies by plan. Accident & illness coverage typically excludes routine care.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                final rail = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On this page',
                            style: Theme.of(context).textTheme.titleMedium!,
                          ),
                          const SizedBox(height: 10),
                          for (final e in _anchorIds.entries) ...[
                            _RailLink(
                              label: e.value,
                              onTap: () => _scrollTo(e.key),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GradientBorder(
                      radius: AppRadii.br24,
                      child: PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get pricing in minutes',
                              style: Theme.of(context).textTheme.titleMedium!,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a quote and we\'ll explain plan settings in context.',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: PrimaryButton(
                                label: 'Get a quote',
                                icon: Icons.pets,
                                onPressed: () => context.go('/quote'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const NoticeBanner(
                      tone: NoticeTone.warning,
                      title: 'Friendly reminder',
                      body:
                          'Coverage details vary by state and policy. This guide is educational and not a contract.',
                      icon: Icons.policy_outlined,
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [main, const SizedBox(height: 16), rail],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: main),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _StickySidebar(
                        topPadding: 16,
                        bottomPadding: 16,
                        child: rail,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Related articles',
                        style: Theme.of(context).textTheme.headlineSmall!,
                      ),
                    ),
                    SecondaryButton(
                      label: 'Back to Learn',
                      icon: Icons.arrow_back,
                      onPressed: () => context.go('/learn'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ResponsiveGrid(
                  gap: 18,
                  children: [
                    for (final a in _relatedArticles(article))
                      ArticleTile(
                        category: a.category,
                        title: a.title,
                        excerpt: a.excerpt,
                        readTime: a.readTime,
                        onTap: () => context.go('/learn/${a.slug}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<_Article> _relatedArticles(_Article current) {
    final all = _articles();
    final sameCategory = all
        .where((a) => a.slug != current.slug && a.category == current.category)
        .toList();
    final fill = all.where((a) => a.slug != current.slug).toList();

    final result = <_Article>[];
    result.addAll(sameCategory.take(3));
    if (result.length < 3) {
      for (final a in fill) {
        if (result.any((r) => r.slug == a.slug)) continue;
        result.add(a);
        if (result.length == 3) break;
      }
    }
    return result;
  }

  static _Article _articleFromSlug(String slug) {
    for (final a in _articles()) {
      if (a.slug == slug) return a;
    }
    return _Article(
      slug: slug,
      category: 'Guide',
      title: _titleFromSlug(slug),
      excerpt:
          'A practical guide to help you understand coverage, claims, and plan settings—without the jargon.',
      readTime: '5 min read',
    );
  }

  static String _titleFromSlug(String slug) {
    final words = slug
        .split('-')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .toList();
    return words.join(' ');
  }

  static List<_Article> _articles() {
    return const [
      _Article(
        slug: 'accident-and-illness-explained',
        category: 'Coverage',
        title: 'Accident & illness coverage: what it really means',
        excerpt:
            'A clear breakdown of common covered costs and the fine print that matters.',
        readTime: '5 min read',
        heroImageAsset: 'assets/images/Cat at vet.png',
      ),
      _Article(
        slug: 'covered-vs-not-covered',
        category: 'Coverage',
        title: 'Covered vs not covered: the simple checklist',
        excerpt:
            'A quick way to predict what\'s likely eligible—and what typically isn\'t.',
        readTime: '4 min read',
        heroImageAsset: 'assets/images/Cat at vet.png',
      ),
      _Article(
        slug: 'deductible-vs-reimbursement',
        category: 'Pricing',
        title: 'Deductible vs reimbursement: choosing the right balance',
        excerpt: 'How plan settings influence premium today and costs later.',
        readTime: '6 min read',
        heroImageAsset: 'assets/images/learning image.png',
      ),
      _Article(
        slug: 'annual-limit-what-to-pick',
        category: 'Pricing',
        title: 'Annual limits: how to pick a number you won\'t regret',
        excerpt:
            'A pragmatic way to think about worst-case scenarios and peace of mind.',
        readTime: '6 min read',
        heroImageAsset: 'assets/images/learning image.png',
      ),
      _Article(
        slug: 'claims-basics',
        category: 'Claims',
        title: 'Claims basics: what to submit and what happens next',
        excerpt:
            'Invoice, medical notes, timelines—and how to avoid back-and-forth.',
        readTime: '5 min read',
        heroImageAsset: 'assets/images/how it works.png',
      ),
      _Article(
        slug: 'claim-timelines',
        category: 'Claims',
        title: 'Claim timelines: why review can take time (and what helps)',
        excerpt:
            'What reviewers look for and how to submit clean documentation.',
        readTime: '5 min read',
        heroImageAsset: 'assets/images/how it works.png',
      ),
    ];
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge!.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Anchor extends StatelessWidget {
  const _Anchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge!),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({required this.term, required this.meaning});

  final String term;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term,
            style: Theme.of(
              context,
            ).textTheme.titleMedium!.copyWith(color: AppColors.deepGreen),
          ),
          const SizedBox(height: 8),
          Text(
            meaning,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RailLink extends StatelessWidget {
  const _RailLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.arrow_right, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Article {
  const _Article({
    required this.slug,
    required this.category,
    required this.title,
    required this.excerpt,
    required this.readTime,
    this.heroImageAsset,
  });

  final String slug;
  final String category;
  final String title;
  final String excerpt;
  final String readTime;
  final String? heroImageAsset;
}

class _StickySidebar extends StatefulWidget {
  const _StickySidebar({
    required this.child,
    this.topPadding = 16,
    this.bottomPadding = 16,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;

  @override
  State<_StickySidebar> createState() => _StickySidebarState();
}

class _StickySidebarState extends State<_StickySidebar> {
  final _containerKey = GlobalKey();
  final _childKey = GlobalKey();

  ScrollController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PrimaryScrollController.maybeOf(context);
    if (_controller == next) return;
    _controller?.removeListener(_onScroll);
    _controller = next;
    _controller?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {});
  }

  double _computeTranslateY() {
    final containerCtx = _containerKey.currentContext;
    final childCtx = _childKey.currentContext;
    if (containerCtx == null || childCtx == null) return 0;

    final containerBox = containerCtx.findRenderObject();
    final childBox = childCtx.findRenderObject();
    if (containerBox is! RenderBox || childBox is! RenderBox) return 0;

    final containerTop = containerBox.localToGlobal(Offset.zero).dy;
    final containerHeight = containerBox.size.height;
    final childHeight = childBox.size.height;

    final desiredTop = widget.topPadding;
    final raw = desiredTop - containerTop;
    final minTranslate = 0.0;
    final maxTranslate = math.max(
      0.0,
      containerHeight - childHeight - widget.bottomPadding,
    );

    return raw.clamp(minTranslate, maxTranslate);
  }

  @override
  Widget build(BuildContext context) {
    final translateY = _computeTranslateY();

    return KeyedSubtree(
      key: _containerKey,
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, translateY),
            child: KeyedSubtree(key: _childKey, child: widget.child),
          ),
        ],
      ),
    );
  }
}

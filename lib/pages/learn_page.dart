import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class _Article {
  const _Article(
      {required this.title,
      required this.summary,
      required this.tags,
      required this.readTime});
  final String title;
  final String summary;
  final List<String> tags;
  final String readTime;
}

const _articles = <_Article>[
  _Article(
      title: 'What does pet insurance actually cover?',
      summary:
          'A plain-language breakdown of accident & illness plans, accident-only plans, and common exclusions.',
      tags: ['Coverage'],
      readTime: '4 min'),
  _Article(
      title: 'How deductibles, reimbursement, and limits work together',
      summary:
          'Understand the three settings that shape your premium and your out-of-pocket costs.',
      tags: ['Pricing'],
      readTime: '5 min'),
  _Article(
      title: 'Pre-existing conditions explained',
      summary:
          'What counts as pre-existing, how insurers evaluate medical history, and what to expect.',
      tags: ['Coverage', 'Pre-existing'],
      readTime: '3 min'),
  _Article(
      title: 'How to file a pet insurance claim',
      summary:
          'Step-by-step: from vet visit to reimbursement \u2014 including what documents you need.',
      tags: ['Claims'],
      readTime: '4 min'),
  _Article(
      title: 'Is pet insurance worth it?',
      summary:
          'A realistic look at when insurance makes sense, what it costs, and how to decide.',
      tags: ['Pricing'],
      readTime: '6 min'),
  _Article(
      title: 'Choosing the right plan for your pet',
      summary:
          'How breed, age, and lifestyle affect your coverage needs \u2014 and what to prioritize.',
      tags: ['Coverage', 'Pricing'],
      readTime: '5 min'),
  _Article(
      title: 'What to expect during the waiting period',
      summary:
          'Why waiting periods exist, how long they last, and what happens if your pet gets sick before they end.',
      tags: ['Coverage'],
      readTime: '3 min'),
  _Article(
      title: 'Understanding wellness vs. insurance coverage',
      summary:
          'Why wellness isn\u2019t included in standard plans and how to budget for routine care.',
      tags: ['Coverage', 'Vet care'],
      readTime: '4 min'),
  _Article(
      title: 'Common claim mistakes and how to avoid them',
      summary:
          'Tips to make the claims process smooth: documentation, timing, and record-keeping.',
      tags: ['Claims'],
      readTime: '3 min'),
  _Article(
      title: 'How Clovara is different from traditional pet insurance',
      summary:
          'Transparency, plain language, and a modern claims experience \u2014 here\u2019s what sets us apart.',
      tags: ['Coverage'],
      readTime: '4 min'),
];

const _allTags = [
  'All',
  'Coverage',
  'Pricing',
  'Claims',
  'Pre-existing',
  'Vet care'
];

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String _selectedTag = 'All';

  List<_Article> get _filtered => _selectedTag == 'All'
      ? _articles
      : _articles.where((a) => a.tags.contains(_selectedTag)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(verticalPadding: 28, child: MaxWidth(child: _LearnHero())),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow(label: 'Topics'),
                  const SizedBox(height: 12),
                  Text('Browse by topic',
                      style:
                          Theme.of(context).textTheme.headlineLarge!),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final tag in _allTags)
                      _FilterChip(
                          label: tag,
                          selected: _selectedTag == tag,
                          onTap: () =>
                              setState(() => _selectedTag = tag)),
                  ]),
                  const SizedBox(height: 28),
                  ...[
                    for (int i = 0; i < _filtered.length; i++) ...[
                      _ArticleCard(article: _filtered[i]),
                      if (i < _filtered.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                  if (_filtered.isEmpty)
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: Text('No articles for this topic yet.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                        color: AppColors.textMuted)))),
                ]),
          ),
        ),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _LearnClosingCta())),
      ],
    );
  }
}

class _LearnHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Learn'),
              const SizedBox(height: 14),
              Text(
                  'Learn how pet insurance actually works',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Short, clear guides to help you understand coverage, pricing, and claims \u2014 before you buy.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
            ]),
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: selected ? AppColors.deepGreen : AppColors.surface1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    selected ? AppColors.deepGreen : AppColors.border)),
        child: Text(label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});
  final _Article article;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              for (final tag in article.tags) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(tag,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Text(article.readTime,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(
                          color: AppColors.textSubtle, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Text(article.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(article.summary,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.5)),
          ]),
    );
  }
}

class _LearnClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('Ready to see what it costs?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Get a personalized price for your pet in about two minutes.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = ElevatedButton(
            onPressed: () => context.go('/quote'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.deepGreen,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 18),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.br12),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            child: const Text('See your price'));
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}

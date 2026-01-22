import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/article_tile.dart';
import '../ui/components/badges.dart';
import '../ui/components/bento_grid.dart';
import '../ui/components/buttons.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/hero_stage.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_break.dart';
import '../ui/components/section.dart';
import '../ui/helpers/responsive_grid.dart';
import '../ui/tokens.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String _filter = 'All';

  static const filters = [
    'All',
    'Coverage',
    'Pricing',
    'Claims',
    'Pre-existing',
    'Vet care',
  ];

  @override
  Widget build(BuildContext context) {
    final articles = _articles().where((a) {
      if (_filter == 'All') return true;
      return a.category == _filter;
    }).toList();

    return Column(
      children: [
        Section(
          child: MaxWidth(
            child: HeroStage(
              left: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn: pet insurance, explained like a friend would.',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall!.copyWith(fontSize: 38),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Short guides to help you choose coverage, understand claims, and avoid surprise assumptions.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final f in filters)
                          Pill(
                            label: f,
                            isSelected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              right: BentoGrid(
                primary: ClipRRect(
                  borderRadius: AppRadii.br24,
                  child: Container(
                    color: AppColors.surface,
                    child: AspectRatio(
                      aspectRatio: 1.20,
                      child: Image.asset(
                        'assets/images/learning image.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                secondary: const [
                  MiniFeatureTile(
                    icon: Icons.menu_book,
                    title: 'Clear language',
                    body: 'No jargon. No fine print surprises in the basics.',
                  ),
                  MiniFeatureTile(
                    icon: Icons.checklist,
                    title: 'Practical checklists',
                    body: 'Know what to gather before you submit a claim.',
                  ),
                ],
              ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Featured articles',
                        style: Theme.of(context).textTheme.headlineSmall!,
                      ),
                    ),
                    SecondaryButton(
                      label: 'Get a quote',
                      icon: Icons.pets,
                      onPressed: () => context.go('/quote'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ResponsiveGrid(
                  gap: 18,
                  children: [
                    for (final a in articles)
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

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          child: MaxWidth(
            child: GradientBorder(
              radius: AppRadii.br24,
              child: PremiumCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 720;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prefer learning as you go?',
                          style: Theme.of(context).textTheme.headlineSmall!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a quote and we\'ll explain plan settings in context—deductible, reimbursement %, and annual limits.',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          copy,
                          const SizedBox(height: 14),
                          PrimaryButton(
                            label: 'Get a quote',
                            icon: Icons.pets,
                            onPressed: () => context.go('/quote'),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 14),
                        PrimaryButton(
                          label: 'Get a quote',
                          icon: Icons.pets,
                          onPressed: () => context.go('/quote'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_Article> _articles() {
    return const [
      _Article(
        slug: 'accident-and-illness-explained',
        category: 'Coverage',
        title: 'Accident & illness coverage: what it really means',
        excerpt:
            'A clear breakdown of common covered costs and the fine print that matters.',
        readTime: '5 min read',
      ),
      _Article(
        slug: 'covered-vs-not-covered',
        category: 'Coverage',
        title: 'Covered vs not covered: the simple checklist',
        excerpt:
            'A quick way to predict what\'s likely eligible—and what typically isn\'t.',
        readTime: '4 min read',
      ),
      _Article(
        slug: 'deductible-vs-reimbursement',
        category: 'Pricing',
        title: 'Deductible vs reimbursement: choosing the right balance',
        excerpt: 'How plan settings influence premium today and costs later.',
        readTime: '6 min read',
      ),
      _Article(
        slug: 'annual-limit-what-to-pick',
        category: 'Pricing',
        title: 'Annual limits: how to pick a number you won\'t regret',
        excerpt:
            'A pragmatic way to think about worst-case scenarios and peace of mind.',
        readTime: '6 min read',
      ),
      _Article(
        slug: 'claims-basics',
        category: 'Claims',
        title: 'Claims basics: what to submit and what happens next',
        excerpt:
            'Invoice, medical notes, timelines—and how to avoid back-and-forth.',
        readTime: '5 min read',
      ),
      _Article(
        slug: 'claim-timelines',
        category: 'Claims',
        title: 'Claim timelines: why review can take time (and what helps)',
        excerpt:
            'What reviewers look for and how to submit clean documentation.',
        readTime: '5 min read',
      ),
      _Article(
        slug: 'pre-existing-conditions',
        category: 'Pre-existing',
        title: 'Pre-existing conditions: what counts and what doesn\'t',
        excerpt:
            'Symptoms vs diagnosis, medical record review, and common examples.',
        readTime: '7 min read',
      ),
      _Article(
        slug: 'enroll-early-why-it-matters',
        category: 'Pre-existing',
        title: 'Why enrolling early matters more than you think',
        excerpt:
            'A gentle explanation of why timing affects eligibility for future care.',
        readTime: '4 min read',
      ),
      _Article(
        slug: 'choosing-a-vet-in-emergencies',
        category: 'Vet care',
        title: 'Choosing a vet in emergencies: what to ask and what to save',
        excerpt:
            'Tips for itemized invoices and the notes that speed up review.',
        readTime: '6 min read',
      ),
      _Article(
        slug: 'medication-and-followup-coverage',
        category: 'Vet care',
        title: 'Medications and follow-ups: when they\'re typically eligible',
        excerpt:
            'How prescriptions, rechecks, and follow-up visits are commonly handled.',
        readTime: '5 min read',
      ),
    ];
  }
}

class _Article {
  const _Article({
    required this.slug,
    required this.category,
    required this.title,
    required this.excerpt,
    required this.readTime,
  });

  final String slug;
  final String category;
  final String title;
  final String excerpt;
  final String readTime;
}

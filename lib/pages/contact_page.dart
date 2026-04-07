import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ContactHero())),
        Section(
            backgroundColor: AppColors.surface2,
            verticalPadding: 28,
            child: MaxWidth(child: _ContactCards())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ResponseInfo())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ContactClosingCta())),
      ],
    );
  }
}

class _ContactHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Contact'),
              const SizedBox(height: 14),
              Text('We\u2019re here if you need us',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Real people. Real answers. No phone trees, no ticket numbers \u2014 just help when you need it.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
            ]),
      );
    });
  }
}

class _ContactCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'Reach us'),
          const SizedBox(height: 12),
          Text('Get in touch',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text('Choose the option that works best for you.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 680;
            final cards = [
              const _ContactCard(
                  icon: Icons.email_outlined,
                  title: 'General support',
                  detail: 'support@clovara.com',
                  description:
                      'Questions about your policy, claims, or account.'),
              const _ContactCard(
                  icon: Icons.gavel_outlined,
                  title: 'Legal & compliance',
                  detail: 'legal@clovara.com',
                  description:
                      'Regulatory questions, legal notices, or compliance inquiries.'),
            ];
            if (stacked) {
              return Column(children: [
                cards[0],
                const SizedBox(height: 14),
                cards[1],
              ]);
            }
            return IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                ]));
          }),
        ]);
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.description});
  final IconData icon;
  final String title;
  final String detail;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14)),
                child:
                    Icon(icon, size: 22, color: AppColors.deepGreen)),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(detail,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.45)),
          ]),
    );
  }
}

class _ResponseInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'What to expect'),
          const SizedBox(height: 12),
          Text('How we handle inquiries',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 20),
          const _InfoRow(
              icon: Icons.schedule_outlined,
              title: 'Response time',
              body:
                  'We aim to respond to all inquiries within one business day.'),
          const SizedBox(height: 10),
          const _InfoRow(
              icon: Icons.support_agent_outlined,
              title: 'Real people',
              body:
                  'Your message goes to a real person \u2014 not a chatbot or automated queue.'),
          const SizedBox(height: 10),
          const _InfoRow(
              icon: Icons.lock_outline,
              title: 'Secure communication',
              body:
                  'All communications are handled securely. Never share passwords via email.'),
        ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br12,
          border: Border.all(color: AppColors.border)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(icon, size: 20, color: AppColors.deepGreen)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepGreen)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.textMuted,
                              height: 1.45)),
                ])),
          ]),
    );
  }
}

class _ContactClosingCta extends StatelessWidget {
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
              Text('Want the fastest path?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Most questions are answered during the quote process. See your price and learn as you go.',
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

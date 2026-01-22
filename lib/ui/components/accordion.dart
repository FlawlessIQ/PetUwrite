import 'package:flutter/material.dart';

import '../tokens.dart';
import 'premium_card.dart';

class AccordionItem {
  AccordionItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

class Accordion extends StatelessWidget {
  const Accordion({
    super.key,
    required this.items,
  });

  final List<AccordionItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      showShadow: false,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _AccordionTile(item: items[i]),
            if (i != items.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _AccordionTile extends StatefulWidget {
  const _AccordionTile({required this.item});
  final AccordionItem item;

  @override
  State<_AccordionTile> createState() => _AccordionTileState();
}

class _AccordionTileState extends State<_AccordionTile> {
  bool _open = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? AppColors.surface2.withOpacity(0.65) : Colors.transparent;

    return FocusableActionDetector(
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.question,
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      turns: _open ? 0.5 : 0,
                      child: const Icon(Icons.expand_more, color: AppColors.textMuted),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  firstCurve: Curves.easeOutCubic,
                  secondCurve: Curves.easeOutCubic,
                  sizeCurve: Curves.easeOutCubic,
                  crossFadeState:
                      _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      widget.item.answer,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: AppColors.textMuted),
                    ),
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

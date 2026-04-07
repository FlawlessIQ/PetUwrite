#!/usr/bin/env python3
"""Rewrite conversational_quote_flow.dart — Focus Mode UI.

Strategy: Replace 3 blocks of presentation code using section-comment anchors.
All business logic is preserved verbatim.
"""

path = '/Users/conorlawless/Development/Clovara/lib/screens/conversational_quote_flow.dart'

with open(path) as f:
    content = f.read()

# ============================================================
# Define anchors (exact strings that exist in the file)
# ============================================================

# Block A: BUILD section through Avatars section (before Inline options)
A_START = '  // =====================================================================\n  //  BUILD\n  // =====================================================================\n'
A_END   = '  // ---- Inline options --------------------------------------------------\n'

# Block B: Bottom input area through end of state class
B_START = '  // ---- Bottom input area -----------------------------------------------\n'
B_END   = '// ---------------------------------------------------------------------------\n// Reusable pill / button widgets (private to this file)\n// ---------------------------------------------------------------------------\n'

# Block C: _OptionPill class
C_START = 'class _OptionPill extends StatelessWidget {\n'
C_END   = 'class _ActionButton extends StatelessWidget {\n'

# ============================================================
# Validate anchors
# ============================================================
for name, anchor in [('A_START', A_START), ('A_END', A_END), ('B_START', B_START),
                      ('B_END', B_END), ('C_START', C_START), ('C_END', C_END)]:
    assert anchor in content, f'Anchor {name} not found!'

# ============================================================
# Locate positions
# ============================================================
a_start_idx = content.index(A_START)
a_end_idx   = content.index(A_END)
b_start_idx = content.index(B_START)
b_end_idx   = content.index(B_END)
c_start_idx = content.index(C_START)
c_end_idx   = content.index(C_END)

# ============================================================
# New Block A — Focus Mode build, header, focused step,
#               answer chips, thinking state, dot helper
# ============================================================

NEW_A = r'''  // =====================================================================
  //  BUILD — Focus Mode
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    _scheduleAutofocusIfNeeded();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_messages.isEmpty && !_isTyping) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ClovaraColors.clover.withOpacity(0.08),
                      ),
                      child: const Center(child: ClovaraMark(size: 28)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Getting things ready\u2026',
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return MaxWidth(
              maxWidth: 600,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMinimalHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnswerChips(),
                          _buildFocusedStep(),
                        ],
                      ),
                    ),
                  ),
                  if (_isWaitingForInput && _currentQuestion < _questions.length)
                    _buildInputArea(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _scheduleAutofocusIfNeeded() {
    if (!mounted || !_isWaitingForInput || _isTyping) return;
    if (_currentQuestion < 0 || _currentQuestion >= _questions.length) return;

    final question = _questions[_currentQuestion];
    if (question.type == QuestionType.choice ||
        question.type == QuestionType.multiSelect ||
        question.type == QuestionType.breedPicker ||
        question.type == QuestionType.agePicker ||
        question.type == QuestionType.weightPicker) {
      return;
    }

    if (_focusNode.hasFocus && _lastAutofocusQuestionIndex == _currentQuestion) {
      return;
    }
    _lastAutofocusQuestionIndex = _currentQuestion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isWaitingForInput || _isTyping) return;
      if (!_focusNode.canRequestFocus) return;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  // ---- Minimal header --------------------------------------------------

  Widget _buildMinimalHeader() {
    final answered = _messages.where((m) => !m.isBot).length;
    final total = _questions.where((q) => q.shouldShow(_answers)).length;
    final progress = total > 0 ? (answered / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _headerIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () async {
                  if (_answers.isNotEmpty || _messages.isNotEmpty) {
                    final shouldLeave = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Leave quote?'),
                        content: const Text(
                          'If you leave now, your progress may be lost.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Leave'),
                          ),
                        ],
                      ),
                    );
                    if (shouldLeave != true) return;
                  }
                  if (!mounted) return;
                  context.go('/');
                },
              ),
              const SizedBox(width: 8),
              const ClovaraMark(size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  total > 0 ? 'Step ${(answered + 1).clamp(1, total)} of $total' : '',
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_answers.isNotEmpty)
                _headerIconButton(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: 'Save & resume later',
                  onPressed: () => unawaited(_copyResumeCode()),
                ),
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  return _headerIconButton(
                    icon: snapshot.hasData
                        ? Icons.account_circle_outlined
                        : Icons.login_rounded,
                    tooltip: snapshot.hasData ? 'Account' : 'Sign in',
                    onPressed: () {
                      if (snapshot.hasData) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CustomerHomeScreen(isPremium: false),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(ClovaraColors.clover),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: ClovaraColors.forest.withOpacity(0.6), size: 22),
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  // ---- Answer summary chips --------------------------------------------

  Widget _buildAnswerChips() {
    final userMessages = _messages.where((m) => !m.isBot).toList();
    if (userMessages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: userMessages.map((msg) {
          final idx = _messages.indexOf(msg);
          final botMsg = idx > 0
              ? _messages.sublist(0, idx).lastWhere(
                    (m) => m.isBot,
                    orElse: () => msg,
                  )
              : null;
          final chipIcon = _chipIconFor(botMsg?.questionData?.id);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chipIcon != null) ...[
                  Icon(
                    chipIcon,
                    size: 13,
                    color: ClovaraColors.clover.withOpacity(0.65),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  msg.text.length > 30
                      ? '${msg.text.substring(0, 27)}\u2026'
                      : msg.text,
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.forest.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData? _chipIconFor(String? questionId) {
    switch (questionId) {
      case 'welcome':
        return Icons.person_outline;
      case 'petName':
        return Icons.pets;
      case 'species':
        return Icons.category_outlined;
      case 'breed':
        return Icons.search;
      case 'age':
        return Icons.cake_outlined;
      case 'weight':
        return Icons.fitness_center;
      case 'hasConditions':
      case 'conditionTypes':
        return Icons.favorite_outline;
      case 'email':
        return Icons.email_outlined;
      case 'zipCode':
        return Icons.location_on_outlined;
      default:
        return null;
    }
  }

  // ---- Focused step (question + options) --------------------------------

  Widget _buildFocusedStep() {
    final botMessages = _messages.where((m) => m.isBot).toList();
    if (botMessages.isEmpty) {
      return _isTyping ? _buildThinkingState() : const SizedBox.shrink();
    }

    final lastBotMsg = botMessages.last;
    final questionData = lastBotMsg.questionData;
    final hasText = lastBotMsg.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thinking state (before text appears)
        if (_isTyping && !hasText) _buildThinkingState(),

        // Question text — large, prominent
        if (hasText)
          TweenAnimationBuilder<double>(
            key: ValueKey('q_${_messages.length}'),
            duration: const Duration(milliseconds: 350),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, opacity, child) {
              return Opacity(opacity: opacity, child: child);
            },
            child: Text(
              lastBotMsg.text,
              style: ClovaraTypography.h2.copyWith(
                color: ClovaraColors.forest,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.4,
                letterSpacing: -0.3,
              ),
            ),
          ),

        SizedBox(height: _isWaitingForInput ? 28 : 12),

        // Input options (fade + slide in)
        if (_isWaitingForInput && questionData != null)
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildInlineOptions(questionData),
          ),
      ],
    );
  }

  // ---- Thinking state --------------------------------------------------

  Widget _buildThinkingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClovaraMark(size: 16),
            const SizedBox(width: 10),
            ...List.generate(3, (i) => _buildDot(i)),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1.0);
        return Container(
          width: 7,
          height: 7,
          margin: EdgeInsets.only(right: index < 2 ? 5 : 0),
          decoration: BoxDecoration(
            color: ClovaraColors.clover.withOpacity(0.2 + animValue * 0.6),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

'''

# ============================================================
# New Block B — Embedded text input area
# ============================================================

NEW_B = r'''  // ---- Bottom input area -----------------------------------------------

  Widget _buildInputArea() {
    final question = _questions[_currentQuestion];

    // No keyboard input for tappable question types
    if (question.type == QuestionType.choice ||
        question.type == QuestionType.multiSelect ||
        question.type == QuestionType.breedPicker ||
        question.type == QuestionType.agePicker ||
        question.type == QuestionType.weightPicker) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  keyboardType: question.type == QuestionType.number
                      ? TextInputType.number
                      : TextInputType.text,
                  textCapitalization: TextCapitalization.words,
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: question.placeholder ?? 'Type here\u2026',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) _handleUserResponse(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (_textController.text.isNotEmpty) {
                        _handleUserResponse(_textController.text);
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

'''

# ============================================================
# New Block C — Restyled _OptionPill (card-like, softer)
# ============================================================

NEW_C = r'''class _OptionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionPill({
    required this.label,
    this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? ClovaraColors.clover.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ClovaraColors.clover : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.06 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                selected ? Icons.check_circle : icon,
                size: 18,
                color: selected
                    ? ClovaraColors.clover
                    : ClovaraColors.forest.withOpacity(0.45),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: ClovaraTypography.body.copyWith(
                color: ClovaraColors.forest,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

'''

# ============================================================
# Assemble
# ============================================================

part1 = content[:a_start_idx]        # everything before BUILD section
part_inline = content[a_end_idx:b_start_idx]  # inline option builders (keep as-is)
part_post = content[b_end_idx:c_start_idx]    # pill comment + blank lines
part_after = content[c_end_idx:]              # _ActionButton + _HorizontalScrollPicker

new_content = part1 + NEW_A + part_inline + NEW_B + part_post + NEW_C + part_after

with open(path, 'w') as f:
    f.write(new_content)

print(f'✅ Rewrote conversational_quote_flow.dart ({len(new_content)} chars)')
print(f'   Block A: {a_start_idx}-{a_end_idx} → new focus-mode UI')
print(f'   Block B: {b_start_idx}-{b_end_idx} → new input area')
print(f'   Block C: {c_start_idx}-{c_end_idx} → new option pill')

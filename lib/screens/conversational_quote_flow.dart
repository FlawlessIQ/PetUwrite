import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai/clover_response_adapter.dart';
import '../data/breed_catalog.dart';
import '../services/breed_size_guide.dart';
import '../models/owner.dart';
import '../models/pet.dart';
import '../screens/ai_analysis_screen_v2.dart';
import '../auth/customer_home_screen.dart';
import '../auth/login_screen.dart';
import '../services/conversational_ai_service.dart';
import '../services/draft_service.dart';
import '../services/marketing_attribution_service.dart';
import '../services/underwriting_rules_engine.dart';
import '../services/user_session_service.dart';
import '../theme/clovara_theme.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/max_width.dart';
import '../ui/components/save_resume_dialog.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

enum QuestionType {
  text,
  number,
  choice,
  multiSelect,
  breedPicker,
  agePicker,
  weightPicker,

  /// Legacy type kept for compatibility — not used in the new flow.
  petQuickDetails,
  ageSlider,
}

class QuestionData {
  final String id;
  final String question;
  final QuestionType type;
  final String field;
  final String? placeholder;
  final String? suffix;
  final List<ChoiceOption>? options;
  final bool Function(Map<String, dynamic>)? condition;
  final String? subtitle;

  QuestionData({
    required this.id,
    required this.question,
    required this.type,
    required this.field,
    this.placeholder,
    this.suffix,
    this.options,
    this.condition,
    this.subtitle,
  });

  bool shouldShow(Map<String, dynamic> answers) {
    return condition == null || condition!(answers);
  }
}

class ChoiceOption {
  final dynamic value;
  final String label;
  final IconData icon;

  ChoiceOption({required this.value, required this.label, required this.icon});
}

class QuickReply {
  final String value;
  final String label;

  const QuickReply({required this.value, required this.label});
}

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;
  final QuestionData? questionData;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
    this.questionData,
  });
}

// ---------------------------------------------------------------------------
// Main Widget
// ---------------------------------------------------------------------------

class ConversationalQuoteFlow extends StatefulWidget {
  const ConversationalQuoteFlow({
    super.key,
    this.restorePendingDraft = false,
  });

  final bool restorePendingDraft;

  @override
  State<ConversationalQuoteFlow> createState() =>
      _ConversationalQuoteFlowState();
}

class _ConversationalQuoteFlowState extends State<ConversationalQuoteFlow>
    with TickerProviderStateMixin {
  // ---- State ----------------------------------------------------------
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  final Map<String, dynamic> _answers = {};

  int _currentQuestion = 0;
  bool _isTyping = false;
  bool _isWaitingForInput = false;
  String _activePromptText = '';

  // Confirmation flow
  bool _awaitingConfirmation = false;
  dynamic _pendingValue;
  String? _pendingField;

  // Services
  late ConversationalAIService _aiService;
  late CloverResponseAdapter _cloverAdapter;
  EligibilityResult? _earlyEligibility;

  // Auth
  StreamSubscription<User?>? _authSubscription;

  // Autofocus tracking
  int _lastAutofocusQuestionIndex = -1;



  // ---- Questions (one-per-step) -----------------------------------------
  late final List<QuestionData> _questions = [
    // 0 — Owner name
    QuestionData(
      id: 'welcome',
      question: "Let's find the right plan for your pet. What's your first name?",
      type: QuestionType.text,
      field: 'ownerName',
      placeholder: 'Your first name',
      subtitle: 'This takes about two minutes.',
    ),
    // 1 — Pet name
    QuestionData(
      id: 'petName',
      question: "Great to meet you, {ownerName}. What's your pet's name?",
      type: QuestionType.text,
      field: 'petName',
      placeholder: "Your pet's name",
    ),
    // 2 — Species
    QuestionData(
      id: 'species',
      question: "Is {petName} a dog or a cat?",
      type: QuestionType.choice,
      field: 'species',
      options: [
        ChoiceOption(value: 'dog', label: 'Dog', icon: Icons.pets),
        ChoiceOption(value: 'cat', label: 'Cat', icon: Icons.pets),
      ],
    ),
    // 3 — Sex
    QuestionData(
      id: 'sex',
      question: "And is {petName} male or female?",
      type: QuestionType.choice,
      field: 'gender',
      options: [
        ChoiceOption(value: 'male', label: 'Male', icon: Icons.male),
        ChoiceOption(value: 'female', label: 'Female', icon: Icons.female),
      ],
    ),
    // 4 — Spayed / Neutered
    QuestionData(
      id: 'neutered',
      question: "Is {petName} spayed or neutered?",
      type: QuestionType.choice,
      field: 'isNeutered',
      options: [
        ChoiceOption(value: true, label: 'Yes', icon: Icons.check_circle_outline),
        ChoiceOption(value: false, label: 'No', icon: Icons.cancel_outlined),
      ],
    ),
    // 5 — Breed
    QuestionData(
      id: 'breed',
      question: "What breed is {petName}?",
      type: QuestionType.breedPicker,
      field: 'breed',
      placeholder: 'Search or pick a breed',
      subtitle: 'You can search or choose a common breed.',
    ),
    // 6 — Age
    QuestionData(
      id: 'age',
      question: "How old is {petName}?",
      type: QuestionType.agePicker,
      field: 'age',
      subtitle: 'A quick estimate is perfect.',
    ),
    // 7 — Weight
    QuestionData(
      id: 'weight',
      question: "About how much does {petName} weigh?",
      type: QuestionType.weightPicker,
      field: 'weight',
      subtitle: 'A rough number is all I need.',
    ),
    // 8 — Pre-existing conditions
    QuestionData(
      id: 'hasConditions',
      question: "Has {petName} ever been diagnosed with a health condition?",
      type: QuestionType.choice,
      field: 'hasPreExistingConditions',
      options: [
        ChoiceOption(value: false, label: 'None — healthy!', icon: Icons.favorite_outline),
        ChoiceOption(value: true, label: 'Yes', icon: Icons.medical_services_outlined),
      ],
    ),
    // 9 — Condition types (conditional)
    QuestionData(
      id: 'conditionTypes',
      question: "Which of these applies to {petName}?",
      type: QuestionType.multiSelect,
      field: 'preExistingConditionTypes',
      condition: (a) => a['hasPreExistingConditions'] == true,
      subtitle: 'Choose every condition that fits.',
      options: [
        ChoiceOption(value: 'Allergies / Skin', label: 'Allergies / Skin', icon: Icons.healing),
        ChoiceOption(value: 'Joint / Mobility', label: 'Joint / Mobility', icon: Icons.accessibility_new),
        ChoiceOption(value: 'Digestive', label: 'Digestive', icon: Icons.restaurant),
        ChoiceOption(value: 'Heart', label: 'Heart', icon: Icons.favorite),
        ChoiceOption(value: 'Cancer', label: 'Cancer', icon: Icons.local_hospital),
        ChoiceOption(value: 'Diabetes', label: 'Diabetes', icon: Icons.bloodtype),
        ChoiceOption(value: 'Thyroid', label: 'Thyroid', icon: Icons.science),
        ChoiceOption(value: 'Kidney / Urinary', label: 'Kidney / Urinary', icon: Icons.water_drop),
        ChoiceOption(value: 'Other', label: 'Other', icon: Icons.more_horiz),
      ],
    ),
    // 10 — Other condition text (conditional)
    QuestionData(
      id: 'conditionOtherText',
      question: "Tell me a little more about the other condition.",
      type: QuestionType.text,
      field: 'preExistingConditionOtherText',
      placeholder: 'e.g. epilepsy, ear infections, etc.',
      condition: (a) {
        final types = a['preExistingConditionTypes'];
        return types is List && types.contains('Other');
      },
    ),
    // 11 — Treatment status (conditional)
    QuestionData(
      id: 'conditionTreatment',
      question: "Is {petName} receiving treatment or medication right now?",
      type: QuestionType.choice,
      field: 'isReceivingTreatment',
      condition: (a) => a['hasPreExistingConditions'] == true,
      options: [
        ChoiceOption(value: 'managed', label: 'Yes — managed with treatment', icon: Icons.check_circle),
        ChoiceOption(value: false, label: 'Not currently', icon: Icons.pause_circle_outline),
        ChoiceOption(value: 'unsure', label: "I'm not sure", icon: Icons.help_outline),
      ],
    ),
    // 12 — Email
    QuestionData(
      id: 'email',
      question: "Where should I send the quote?",
      type: QuestionType.text,
      field: 'email',
      placeholder: 'you@email.com',
      subtitle: 'I’ll send the quote summary here.',
    ),
    // 13 — Zip code
    QuestionData(
      id: 'zipCode',
      question: "What zip code should I price for?",
      type: QuestionType.text,
      field: 'zipCode',
      placeholder: '10001',
      subtitle: 'Rates can vary slightly by location.',
    ),
  ];

  // ---- Lifecycle -------------------------------------------------------

  @override
  void initState() {
    super.initState();
    MarketingAttributionService().ensureSessionStarted();
    _aiService = ConversationalAIService();
    _cloverAdapter = CloverResponseAdapter();
    if (!widget.restorePendingDraft) {
      unawaited(_clearStaleLocalProgress());
    }
    _setupAuthListener();
    unawaited(_ensureAnonymousSession());
    _prefillUserData();
    _startConversation();
  }

  /// Silently establish an anonymous Firebase session so Firestore writes,
  /// Cloud Function calls, and Storage uploads work without requiring the
  /// user to create an account. Real auth is only needed at checkout.
  Future<void> _ensureAnonymousSession() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) return;
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('[QuoteFlow] Anonymous auth failed (non-blocking): $e');
    }
  }

  @override
  void dispose() {
    unawaited(_savePendingQuote());
    _authSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _prefillUserData();
      }
    });
  }

  // ---- Persistence -----------------------------------------------------

  Future<void> _savePendingQuote() async {
    if (_answers.isEmpty) return;
    try {
      await UserSessionService().savePendingQuote(_answers);
      try {
        final draftService = DraftService();
        await draftService.upsertQuoteDraft(quoteData: _answers);
      } catch (_) {
        // Draft save is best-effort
      }
    } catch (e) {
      print('⚠️ Error saving pending quote: $e');
    }
  }

  Future<void> _copyResumeCode() async {
    await _savePendingQuote();
    if (!mounted) return;
    SaveResumeDialog.show(context, ensureSaved: () => _savePendingQuote());
  }

  Future<void> _clearStaleLocalProgress() async {
    try {
      await UserSessionService().clearPendingQuote();
      await UserSessionService().clearPendingCheckout();
    } catch (e) {
      print('⚠️ Error clearing stale local quote progress: $e');
    }
  }

  // ---- Pre-fill --------------------------------------------------------

  Future<void> _prefillUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _answers['ownerName'] ??= user.displayName;
        }
        if (user.email != null && user.email!.isNotEmpty) {
          _answers['email'] ??= user.email;
        }
      }

      final profile = await UserSessionService().getUserProfile();
      if (profile.isNotEmpty) {
        if (profile['firstName'] != null) {
          _answers['ownerName'] ??=
              '${profile['firstName']} ${profile['lastName'] ?? ''}'.trim();
        }
        if (profile['email'] != null) {
          _answers['email'] ??= profile['email'];
        }
        if (profile['zipCode'] != null) {
          _answers['zipCode'] ??= profile['zipCode'];
        }
      }

      if (widget.restorePendingDraft) {
        final pending = await UserSessionService().getPendingQuote();
        if (pending != null && pending.isNotEmpty) {
          for (final entry in pending.entries) {
            _answers[entry.key] ??= entry.value;
          }
        }
      }
    } catch (e) {
      print('⚠️ Error prefilling user data: $e');
    }
  }

  // ---- Conversation engine ---------------------------------------------

  Future<void> _startConversation() async {
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    _showNextQuestion();
  }

  Future<void> _showNextQuestion() async {
    // Skip questions whose conditions aren't met or that are pre-filled
    while (_currentQuestion < _questions.length) {
      final q = _questions[_currentQuestion];
      if (!q.shouldShow(_answers)) {
        _currentQuestion++;
        continue;
      }
      // If already answered, skip
      if (_hasMeaningfulAnswer(_answers[q.field])) {
        _currentQuestion++;
        continue;
      }
      break;
    }

    if (_currentQuestion >= _questions.length) {
      _completeQuote();
      return;
    }

    final question = _questions[_currentQuestion];

    setState(() {
      _isTyping = true;
      _isWaitingForInput = false;
      _activePromptText = '';
    });

    // Keep question prompts deterministic so the guided flow has a stable,
    // intentional rhythm instead of varying prompt copy step to step.
    String questionText = _formatQuestion(question.question);

    await Future.delayed(
      Duration(
        milliseconds: switch (question.type) {
          QuestionType.text => 120,
          QuestionType.choice => 90,
          QuestionType.multiSelect => 110,
          QuestionType.breedPicker => 110,
          QuestionType.agePicker => 90,
          QuestionType.weightPicker => 90,
          _ => 100,
        },
      ),
    );

    // Stream the bot message
    await _streamBotMessage(questionText, question);

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 90));
    setState(() {
      _isTyping = false;
      _isWaitingForInput = true;
    });

    _scrollToBottom();
  }

  Future<void> _streamBotMessage(String text, QuestionData question) async {
    final msg = ChatMessage(
      text: '',
      isBot: true,
      timestamp: DateTime.now(),
      questionData: question,
    );

    setState(() => _messages.add(msg));

    // Chunked streaming animation
    await Future.delayed(const Duration(milliseconds: 70));
    final totalUpdates = text.length < 70
      ? 12 + math.Random().nextInt(5)
      : 16 + math.Random().nextInt(6);
    final charsPerTick = math.max(1, (text.length / totalUpdates).ceil());
    int shown = 0;
    while (shown < text.length) {
      shown = math.min(shown + charsPerTick, text.length);
      if (!mounted) return;
      setState(() {
        _activePromptText = text.substring(0, shown);
        _messages[_messages.length - 1] = ChatMessage(
          text: text.substring(0, shown),
          isBot: true,
          timestamp: msg.timestamp,
          questionData: question,
        );
      });
      await Future.delayed(
        Duration(milliseconds: 16 + math.Random().nextInt(8)),
      );
    }

    _scrollToBottom();
  }

  // ---- Response handling -----------------------------------------------

  Future<void> _handleUserResponse(dynamic value, {String? displayText}) async {
    // Confirmation flow
    if (_awaitingConfirmation) {
      final isYes = value is String &&
          ['yes', 'y', 'correct', 'yep', 'yeah', 'right']
              .contains(value.trim().toLowerCase());
      final isNo = value is String &&
          ['no', 'n', 'wrong', 'nope', 'change']
              .contains(value.trim().toLowerCase());

      if (isYes && _pendingField != null) {
        final confirmedField = _pendingField!;
        final confirmedValue = _pendingValue;
        _answers[_pendingField!] = _pendingValue;
        _awaitingConfirmation = false;
        _pendingField = null;
        _pendingValue = null;

        _addUserMessage(displayText ?? value.toString());
        _textController.clear();
        _currentQuestion++;
        await _tryUpdateUserProfile(confirmedField, confirmedValue);
        await Future.delayed(const Duration(milliseconds: 220));
        _showNextQuestion();
        return;
      } else if (isNo) {
        _awaitingConfirmation = false;
        _pendingField = null;
        _pendingValue = null;

        _addUserMessage(displayText ?? value.toString());
        _textController.clear();

        setState(() {
          _isTyping = true;
          _isWaitingForInput = false;
        });
        await Future.delayed(const Duration(milliseconds: 280));
        if (_currentQuestion >= 0 && _currentQuestion < _questions.length) {
          await _streamBotMessage(
            "Thanks — let’s fix that.",
            _questions[_currentQuestion],
          );
        }
        setState(() {
          _isTyping = false;
          _isWaitingForInput = true;
        });
        return;
      }
    }

    if (_currentQuestion < 0 || _currentQuestion >= _questions.length) return;
    final question = _questions[_currentQuestion];
    final hadExistingAnswer = _hasMeaningfulAnswer(_answers[question.field]);
    final previousValue = _answers[question.field];

    // Display the user's message
    _addUserMessage(displayText ?? value.toString());
    _textController.clear();

    setState(() {
      _isWaitingForInput = false;
      _isTyping = true;
    });

    // Validate text inputs with AI
    if (question.type == QuestionType.text && value is String) {
      try {
        final validation = await _aiService
            .validateAndCorrectInput(
              questionId: question.id,
              userInput: value,
              context: _answers,
            )
            .timeout(const Duration(seconds: 3));
        if (validation['needsConfirmation'] == true) {
          final corrected = validation['correctedValue'] ?? validation['corrected'];
          if (corrected != null && corrected != value) {
            _pendingValue = corrected;
            _pendingField = question.field;
            _awaitingConfirmation = true;
            await _streamBotMessage(
              "Did you mean \"$corrected\"?",
              question,
            );
            setState(() {
              _isTyping = false;
              _isWaitingForInput = true;
            });
            return;
          }
        }
      } catch (_) {
        // Validation failure is non-blocking
      }
    }

    // Commit the answer
    _answers[question.field] = value;
  _clearDependentAnswers(question, previousValue: previousValue, nextValue: value);

    // Handle conditions flow
    if (question.id == 'conditionTypes') {
      await _handleConditionSelection(value);
    } else if (question.id == 'hasConditions' && value == true) {
      // Empathetic transition to condition types
      await Future.delayed(const Duration(milliseconds: 240));
    }

    // Update user profile if applicable
    await _tryUpdateUserProfile(question.field, value);

    final nextVisibleQuestion = _nextVisibleQuestionIndex(fromIndex: _currentQuestion);

    _currentQuestion++;

    await Future.delayed(const Duration(milliseconds: 240));
    if (hadExistingAnswer) {
      if (nextVisibleQuestion != null) {
        _currentQuestion = nextVisibleQuestion;
        _presentCurrentQuestion();
      } else {
        _currentQuestion = _currentQuestion.clamp(0, _questions.length - 1);
        _presentCurrentQuestion();
      }
      return;
    }
    await _showNextQuestion();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isBot: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  Future<void> _tryUpdateUserProfile(String field, dynamic value) async {
    try {
      if (field == 'ownerName' && value is String && value.isNotEmpty) {
        final parts = value.trim().split(' ');
        await UserSessionService().updateUserProfile(
          firstName: parts.first,
          lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
        );
      } else if (field == 'zipCode' && value is String && value.isNotEmpty) {
        await UserSessionService().updateUserProfile(zipCode: value);
      }
    } catch (e) {
      print('⚠️ Error updating user profile: $e');
    }
  }

  Future<void> _handleConditionSelection(dynamic answer) async {
    final petName = _answers['petName'] as String? ?? 'your pet';
    final conditions =
        answer is List ? answer.map((e) => e.toString()).toList() : <String>[];
    if (conditions.isNotEmpty && _currentQuestion < _questions.length) {
      await Future.delayed(const Duration(milliseconds: 400));
      await _streamBotMessage(
        "Thanks for sharing that about $petName. I know health stuff can be stressful — we'll take it step by step.",
        _questions[_currentQuestion],
      );
      await Future.delayed(const Duration(milliseconds: 600));

      try {
        final pet = _createPetFromAnswers();
        final quick = await UnderwritingRulesEngine().quickCheck(
          pet,
          conditions,
        );
        if (!quick.eligible) {
          _earlyEligibility = quick;
          final joined = conditions.length <= 2
              ? conditions.join(' and ')
              : '${conditions.take(2).join(', ')} and ${conditions.length - 2} more';
          if (_currentQuestion < _questions.length) {
            await _streamBotMessage(
              "One quick note: based on what you selected ($joined), we may not be able to offer a new policy for $petName. I'll still finish this up so we can confirm and share next steps.",
              _questions[_currentQuestion],
            );
          }
          await Future.delayed(const Duration(milliseconds: 900));
        }
      } catch (e) {
        print('⚠️ Early underwriting quickCheck failed: $e');
      }
    }
  }

  // ---- Completion ------------------------------------------------------

  void _completeQuote() async {
    try {
      final petName = _answers['petName'] as String? ?? 'your pet';

      setState(() {
        _isTyping = true;
        _isWaitingForInput = false;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      final celebrationMessage = _cloverAdapter.formatCelebration(
        petName: petName,
        achievement: "Let me calculate the best plan options for $petName.",
      );
      await _streamBotMessage(celebrationMessage, _questions.last);

      setState(() => _isTyping = false);

      final pet = _createPetFromAnswers();
      final owner = _createOwnerFromAnswers();

      final bool needsMedicalUnderwriting =
          pet.preExistingConditions.isNotEmpty ||
          (pet.isReceivingTreatment == true);

      if (mounted) {
        unawaited(UserSessionService().clearPendingQuote());

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIAnalysisScreen(
              pet: pet,
              routeArguments: {
                'petData': _answers,
                'pet': pet,
                'owner': owner,
                'quoteFlow': 'conversational',
                'needsMedicalUnderwriting': needsMedicalUnderwriting,
                if (_earlyEligibility != null &&
                    _earlyEligibility!.eligible == false)
                  'earlyDeclineReason': _earlyEligibility!.reason,
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Risk calculation error: $e');
      final petNameStr = _answers['petName'] as String? ?? 'your pet';
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ClovaraColors.kWarmCoral),
                const SizedBox(width: 12),
                const Text('Unable to Calculate Risk'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We encountered an issue analyzing $petNameStr's profile, but we can still show you our available plans.",
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                Text(
                  'Error: ${e.toString().replaceAll('Exception: ', '')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: ClovaraColors.clover,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Back'),
              ),
            ],
          ),
        );
      }
    }
  }

  // ---- Model builders --------------------------------------------------

  Pet _createPetFromAnswers() {
    final ageValue = _answers['age'];
    final age = ageValue is String ? int.parse(ageValue) : ageValue as int;
    final dateOfBirth = DateTime.now().subtract(Duration(days: age * 365));

    final weightValue = _answers['weight'];
    final weight = weightValue is String
        ? double.parse(weightValue) * 0.453592
        : (weightValue as num).toDouble() * 0.453592;

    List<String> conditions = [];
    final hasPreExistingFlag = _answers['hasPreExistingConditions'] == true;
    final conditionTypesRaw = _answers['preExistingConditionTypes'];
    final otherTextRaw = _answers['preExistingConditionOtherText'];
    final otherText = otherTextRaw is String ? otherTextRaw.trim() : '';

    final hasTypedConditions =
        conditionTypesRaw is List && conditionTypesRaw.isNotEmpty;
    final inferredHasConditions =
        hasPreExistingFlag || hasTypedConditions || otherText.isNotEmpty;

    if (inferredHasConditions) {
      if (hasTypedConditions) {
        conditions = List<String>.from(conditionTypesRaw);
      }

      if (otherText.isNotEmpty) {
        if (conditions.isEmpty) {
          conditions = [otherText];
        } else {
          conditions =
              conditions.map((c) => c == 'Other' ? otherText : c).toList();
          if (!conditions.contains(otherText) &&
              conditions.any((c) => c == 'Other')) {
            conditions.add(otherText);
          }
        }
      }

      if (conditions.isEmpty) {
        conditions = ['Pre-existing condition reported'];
      }

      conditions = conditions
          .map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList();
    }

    final treatmentAnswer = _answers['isReceivingTreatment'];
    final bool? isReceivingTreatment = treatmentAnswer == null
        ? null
        : (treatmentAnswer == true ||
                (treatmentAnswer is String &&
                    treatmentAnswer.toLowerCase() == 'managed'))
            ? true
            : (treatmentAnswer == false)
                ? false
                : null;

    return Pet(
      id: 'pet_${DateTime.now().millisecondsSinceEpoch}',
      name: _answers['petName'] as String,
      species: _answers['species'] as String,
      breed: _answers['breed'] as String,
      dateOfBirth: dateOfBirth,
      gender: _answers['gender'] as String,
      weight: weight,
      isNeutered: _answers['isNeutered'] as bool,
      preExistingConditions: conditions,
      isReceivingTreatment: isReceivingTreatment,
    );
  }

  Owner _createOwnerFromAnswers() {
    final email = _answers['email'] as String;
    final zipCode = _answers['zipCode'] as String;
    final ownerName = _answers['ownerName'] as String;
    final nameParts = ownerName.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    return Owner(
      id: 'owner_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: '',
      address: Address(
        street: '',
        city: '',
        state: '',
        zipCode: zipCode,
        country: 'USA',
      ),
    );
  }

  // ---- Helpers ---------------------------------------------------------

  String _formatQuestion(String question) {
    String formatted = question;
    _answers.forEach((key, value) {
      formatted = formatted.replaceAll('{$key}', value.toString());
    });
    return formatted;
  }

  String _stepCategory() {
    if (_currentQuestion >= _questions.length) return 'Almost done';
    final id = _questions[_currentQuestion].id;
    switch (id) {
      case 'welcome':
      case 'email':
      case 'zipCode':
        return 'About you';
      case 'petName':
      case 'species':
      case 'sex':
      case 'neutered':
      case 'breed':
      case 'age':
      case 'weight':
        return 'About your pet';
      case 'hasConditions':
      case 'conditionTypes':
      case 'conditionOtherText':
      case 'conditionTreatment':
        return 'Health history';
      default:
        return 'Guided quote';
    }
  }

  bool _hasMeaningfulAnswer(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  List<int> _visibleQuestionIndices() {
    final indices = <int>[];
    for (var index = 0; index < _questions.length; index++) {
      if (_questions[index].shouldShow(_answers)) {
        indices.add(index);
      }
    }
    return indices;
  }

  int? _previousVisibleQuestionIndex() {
    final visible = _visibleQuestionIndices();
    final position = visible.indexOf(_currentQuestion);
    if (position <= 0) return null;
    return visible[position - 1];
  }

  int? _nextVisibleQuestionIndex({int? fromIndex}) {
    final visible = _visibleQuestionIndices();
    final currentIndex = fromIndex ?? _currentQuestion;
    final position = visible.indexOf(currentIndex);
    if (position == -1 || position >= visible.length - 1) return null;
    return visible[position + 1];
  }

  void _presentCurrentQuestion() {
    if (!mounted || _currentQuestion < 0 || _currentQuestion >= _questions.length) {
      return;
    }

    final question = _questions[_currentQuestion];
    final existingValue = _answers[question.field];
    if (question.type == QuestionType.text || question.type == QuestionType.number) {
      final text = existingValue == null ? '' : existingValue.toString();
      _textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } else {
      _textController.clear();
    }

    setState(() {
      _awaitingConfirmation = false;
      _pendingField = null;
      _pendingValue = null;
      _isTyping = false;
      _isWaitingForInput = true;
      _activePromptText = _formatQuestion(question.question);
    });

    _scrollToBottom();
    _scheduleAutofocusIfNeeded();
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    if (!_questions[index].shouldShow(_answers)) return;
    setState(() {
      _currentQuestion = index;
    });
    _presentCurrentQuestion();
  }

  void _clearDependentAnswers(
    QuestionData question, {
    required dynamic previousValue,
    required dynamic nextValue,
  }) {
    if (_answersEqual(previousValue, nextValue)) {
      _pruneHiddenAnswers();
      return;
    }

    switch (question.field) {
      case 'species':
        _answers.remove('breed');
        _answers.remove('weight');
        break;
      case 'breed':
        _answers.remove('weight');
        break;
      case 'hasPreExistingConditions':
        if (nextValue != true) {
          _answers.remove('preExistingConditionTypes');
          _answers.remove('preExistingConditionOtherText');
          _answers.remove('isReceivingTreatment');
          _earlyEligibility = null;
        }
        break;
      case 'preExistingConditionTypes':
        final selected = nextValue is List
            ? nextValue.map((value) => value.toString()).toList()
            : <String>[];
        if (!selected.contains('Other')) {
          _answers.remove('preExistingConditionOtherText');
        }
        if (selected.isEmpty) {
          _answers.remove('isReceivingTreatment');
          _earlyEligibility = null;
        }
        break;
    }

    _pruneHiddenAnswers();
  }

  void _pruneHiddenAnswers() {
    final visibleFields = _questions
        .where((question) => question.shouldShow(_answers))
        .map((question) => question.field)
        .toSet();
    final knownFields = _questions.map((question) => question.field).toSet();
    final staleFields = _answers.keys
        .where((field) => knownFields.contains(field) && !visibleFields.contains(field))
        .toList(growable: false);

    for (final field in staleFields) {
      _answers.remove(field);
    }
  }

  bool _answersEqual(dynamic previousValue, dynamic nextValue) {
    if (previousValue is List && nextValue is List) {
      return listEquals(previousValue, nextValue);
    }
    return previousValue == nextValue;
  }

  String _displayAnswerForQuestion(QuestionData question) {
    final value = _answers[question.field];
    if (!_hasMeaningfulAnswer(value)) return '';

    switch (question.type) {
      case QuestionType.choice:
        final option = question.options?.cast<ChoiceOption?>().firstWhere(
              (candidate) => candidate?.value == value,
              orElse: () => null,
            );
        return option?.label ?? value.toString();
      case QuestionType.multiSelect:
        final selections = (value as List).map((item) => item.toString()).toList();
        if (selections.length <= 2) {
          return selections.join(', ');
        }
        return '${selections.take(2).join(', ')} +${selections.length - 2}';
      case QuestionType.agePicker:
        final age = value is String ? int.tryParse(value) ?? 0 : (value as num).toInt();
        return age == 0 ? '< 1 year' : '$age year${age == 1 ? '' : 's'}';
      case QuestionType.weightPicker:
        return '$value lbs';
      default:
        return value.toString();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 80) return;

      final target = maxExtent.clamp(0.0, maxExtent);
      final distance = (target - _scrollController.offset).abs();
      if (distance <= 12) return;

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ---- Quick reply data ------------------------------------------------

  List<QuickReply> _getQuickRepliesForQuestion(QuestionData question) {
    final species = (_answers['species'] as String?)?.toLowerCase();
    final breed = _answers['breed'] as String?;

    switch (question.id) {
      case 'breed':
        if (species == 'cat') {
          return const [
            QuickReply(value: 'Domestic Shorthair', label: 'Domestic Shorthair'),
            QuickReply(value: 'Domestic Longhair', label: 'Domestic Longhair'),
            QuickReply(value: 'Siamese', label: 'Siamese'),
            QuickReply(value: 'Maine Coon', label: 'Maine Coon'),
            QuickReply(value: 'Persian', label: 'Persian'),
            QuickReply(value: 'Mixed Breed', label: 'Mixed Breed'),
          ];
        }
        return const [
          QuickReply(value: 'Mixed Breed', label: 'Mixed Breed'),
          QuickReply(value: 'Labrador Retriever', label: 'Labrador'),
          QuickReply(value: 'Golden Retriever', label: 'Golden Retriever'),
          QuickReply(value: 'German Shepherd', label: 'German Shepherd'),
          QuickReply(value: 'French Bulldog', label: 'French Bulldog'),
          QuickReply(value: 'Poodle', label: 'Poodle'),
          QuickReply(value: 'Beagle', label: 'Beagle'),
        ];
      case 'age':
        return const [
          QuickReply(value: '0', label: '< 1 yr'),
          QuickReply(value: '1', label: '1 yr'),
          QuickReply(value: '2', label: '2 yrs'),
          QuickReply(value: '3', label: '3 yrs'),
          QuickReply(value: '5', label: '5 yrs'),
          QuickReply(value: '8', label: '8 yrs'),
          QuickReply(value: '12', label: '12+ yrs'),
        ];
      case 'weight':
        if (species == 'cat') {
          return const [
            QuickReply(value: '7', label: '7 lbs'),
            QuickReply(value: '10', label: '10 lbs'),
            QuickReply(value: '12', label: '12 lbs'),
            QuickReply(value: '15', label: '15 lbs'),
          ];
        }
        final range = BreedSizeGuide.expectedAdultWeightLbs(breed);
        if (range != null) {
          final mid = ((range.minLbs + range.maxLbs) / 2).round();
          return [
            QuickReply(value: range.minLbs.round().toString(), label: '~${range.minLbs.round()} lbs'),
            QuickReply(value: mid.toString(), label: '~$mid lbs'),
            QuickReply(value: range.maxLbs.round().toString(), label: '~${range.maxLbs.round()} lbs'),
          ];
        }
        return const [
          QuickReply(value: '15', label: '15 lbs'),
          QuickReply(value: '35', label: '35 lbs'),
          QuickReply(value: '65', label: '65 lbs'),
          QuickReply(value: '110', label: '110+ lbs'),
        ];
      default:
        return const [];
    }
  }

  // =====================================================================
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
            final isNarrow = constraints.maxWidth < 560;
            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

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
                    child: LayoutBuilder(
                      builder: (context, viewport) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            isNarrow ? 20 : 24,
                            isNarrow ? 14 : 20,
                            isNarrow ? 20 : 24,
                            keyboardOpen ? 16 : (isNarrow ? 24 : 40),
                          ),
                          child: SizedBox(
                            height: math.max(
                              viewport.maxHeight - (keyboardOpen ? 8 : 20),
                              isNarrow ? 420.0 : 500.0,
                            ).toDouble(),
                            child: Column(
                              children: [
                                _buildAnswerChips(),
                                SizedBox(height: isNarrow ? 12 : 20),
                                if (!keyboardOpen) const Spacer(flex: 2),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isNarrow ? 420 : 520,
                                    ),
                                    child: _buildFocusedStep(),
                                  ),
                                ),
                                if (!keyboardOpen) const Spacer(flex: 3),
                                SizedBox(height: isNarrow ? 8 : 14),
                              ],
                            ),
                          ),
                        );
                      },
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
    final visibleQuestions = _questions
      .where((q) => q.shouldShow(_answers))
      .toList(growable: false);
    final total = visibleQuestions.length;
    final currentQuestionId =
      _currentQuestion < _questions.length ? _questions[_currentQuestion].id : null;
    final currentVisibleIndex = currentQuestionId == null
      ? -1
      : visibleQuestions.indexWhere((q) => q.id == currentQuestionId);
    final answeredVisible = visibleQuestions
        .where((q) => _hasMeaningfulAnswer(_answers[q.field]))
        .length;
    final currentStep = total == 0
      ? 0
      : currentVisibleIndex >= 0
        ? currentVisibleIndex + 1
        : answeredVisible.clamp(1, total);
    final progress = total > 0 ? ((currentStep - 1) / total).clamp(0.0, 1.0) : 0.0;
    final previousIndex = _previousVisibleQuestionIndex();
    final nextIndex = _nextVisibleQuestionIndex();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF8),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ClovaraColors.clover.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: ClovaraMark(size: 26)),
              ),
              const SizedBox(width: 10),
              Text(
                'Clovara',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ClovaraColors.forest,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: total > 0
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Step $currentStep',
                              style: ClovaraTypography.bodySmall.copyWith(
                                color: ClovaraColors.forest.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: ' of $total',
                              style: ClovaraTypography.bodySmall.copyWith(
                                color: ClovaraColors.forest.withOpacity(0.35),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
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
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ClovaraColors.clover.withOpacity(0.5),
                        ClovaraColors.clover.withOpacity(0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: previousIndex == null
                      ? null
                      : () => _goToQuestion(previousIndex),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClovaraColors.forest,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap an answer chip to jump back and edit it.',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.forest.withOpacity(0.42),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: nextIndex == null
                      ? null
                      : () => _goToQuestion(nextIndex),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text('Next'),
                  iconAlignment: IconAlignment.end,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClovaraColors.forest,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    final answeredQuestions = _questions
        .where((question) =>
            question.shouldShow(_answers) &&
            _hasMeaningfulAnswer(_answers[question.field]))
        .toList(growable: false);
    if (answeredQuestions.isEmpty) {
      return const SizedBox(height: 40);
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: answeredQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final question = answeredQuestions[index];
          final chipIcon = _chipIconFor(question.id);
          final chipText = _displayAnswerForQuestion(question);
          final isCurrent = _currentQuestion < _questions.length &&
              question.id == _questions[_currentQuestion].id;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isCurrent ? 0.98 : 0.8,
            child: InkWell(
              onTap: () => _goToQuestion(_questions.indexOf(question)),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? ClovaraColors.forest.withOpacity(0.06)
                      : const Color(0xFFF9FAF7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isCurrent
                        ? ClovaraColors.forest.withOpacity(0.2)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chipIcon != null) ...[
                      Icon(
                        chipIcon,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      chipText.length > 28
                          ? '${chipText.substring(0, 25)}...'
                          : chipText,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.forest.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 560;
    if (_currentQuestion < 0 || _currentQuestion >= _questions.length) {
      return _isTyping ? _buildThinkingState() : const SizedBox.shrink();
    }

    final questionData = _questions[_currentQuestion];
    final hasText = _activePromptText.isNotEmpty;
    final isTransitioning = _isTyping && !_isWaitingForInput;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 0 : 4,
          isNarrow ? 10 : 18,
          isNarrow ? 0 : 4,
          isNarrow ? 0 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTransitioning)
              _buildTransitionState(isNarrow: isNarrow)
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ClovaraColors.forest.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _stepCategory(),
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.forest.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(height: isNarrow ? 14 : 18),
              if (_isTyping && !hasText) _buildThinkingState(),
              if (hasText)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation);
                    final scale = Tween<double>(
                      begin: 0.985,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slide,
                        child: ScaleTransition(scale: scale, child: child),
                      ),
                    );
                  },
                  child: Text(
                    _activePromptText,
                    key: ValueKey('${questionData.id}:$_activePromptText'),
                    style: ClovaraTypography.h2.copyWith(
                      color: ClovaraColors.forest,
                      fontSize: isNarrow ? 24 : 28,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              if (questionData.subtitle != null) ...[
                SizedBox(height: isNarrow ? 10 : 12),
                Text(
                  questionData.subtitle!,
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest.withOpacity(0.45),
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    fontSize: isNarrow ? 14 : 15,
                  ),
                ),
              ],
              SizedBox(height: _isWaitingForInput ? (isNarrow ? 24 : 30) : 12),
              if (_isWaitingForInput)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 340),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14.0 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildInlineOptions(questionData),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransitionState({required bool isNarrow}) {
    final petName = (_answers['petName'] as String?)?.trim();

    return Container(
      constraints: BoxConstraints(minHeight: isNarrow ? 188 : 220),
      padding: EdgeInsets.all(isNarrow ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ClovaraColors.forest.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Answer saved',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.forest.withOpacity(0.4),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(height: isNarrow ? 16 : 18),
          Text(
            petName == null || petName.isEmpty
                ? 'I\'m shaping the next question for you.'
                : 'I\'m shaping the next step for $petName.',
            style: ClovaraTypography.h2.copyWith(
              color: ClovaraColors.forest.withOpacity(0.85),
              fontSize: isNarrow ? 22 : 26,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'One clean decision at a time, with the next step already in motion.',
            style: ClovaraTypography.body.copyWith(
              color: ClovaraColors.forest.withOpacity(0.48),
              fontWeight: FontWeight.w500,
              height: 1.45,
              fontSize: isNarrow ? 14 : 15,
            ),
          ),
          SizedBox(height: isNarrow ? 18 : 22),
          _buildThinkingState(compact: true),
        ],
      ),
    );
  }

  // ---- Thinking state --------------------------------------------------

  Widget _buildThinkingState({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 24),
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

  // ---- Inline options --------------------------------------------------

  Widget _buildInlineOptions(QuestionData question) {
    switch (question.type) {
      case QuestionType.choice:
        return _buildChoiceOptions(question);
      case QuestionType.multiSelect:
        return _buildMultiSelectOptions(question);
      case QuestionType.breedPicker:
        return _buildBreedPickerInline(question);
      case QuestionType.agePicker:
        return _buildAgePickerInline(question);
      case QuestionType.weightPicker:
        return _buildWeightPickerInline(question);
      default:
        // text / number: quick-reply chips if available
        return _buildQuickReplyChips(question);
    }
  }

  // ---- Choice pills (single-select) ------------------------------------

  Widget _buildChoiceOptions(QuestionData question) {
    final selectedValue = _answers[question.field];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: question.options!.map((option) {
        return _OptionPill(
          label: option.label,
          icon: option.icon,
          selected: selectedValue == option.value,
          onTap: () => _handleUserResponse(option.value, displayText: option.label),
        );
      }).toList(),
    );
  }

  // ---- Multi-select (conditions) ---------------------------------------

  Widget _buildMultiSelectOptions(QuestionData question) {
    final selectedConditions =
        _answers[question.field] as List<String>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: question.options!.map((option) {
            final isSelected = selectedConditions.contains(option.value);
            return _OptionPill(
              label: option.label,
              icon: option.icon,
              selected: isSelected,
              onTap: () {
                setState(() {
                  final list = List<String>.from(selectedConditions);
                  if (isSelected) {
                    list.remove(option.value);
                  } else {
                    list.add(option.value as String);
                  }
                  _answers[question.field] = list;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            label: selectedConditions.isEmpty
                ? 'Select at least one'
                : 'Continue with ${selectedConditions.length} selected',
            enabled: selectedConditions.isNotEmpty,
            onTap: () {
              final display = selectedConditions.length == 1
                  ? selectedConditions.first
                  : '${selectedConditions.length} conditions selected';
              _handleUserResponse(selectedConditions, displayText: display);
            },
          ),
        ),
      ],
    );
  }

  // ---- Breed picker (inline + search modal) ----------------------------

  Widget _buildBreedPickerInline(QuestionData question) {
    final species = (_answers['species'] as String?)?.toLowerCase();
    final replies = _getQuickRepliesForQuestion(question);
    final selectedBreed = _answers[question.field]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Popular quick-pick chips
        if (replies.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: replies.map((r) {
              return _OptionPill(
                label: r.label,
                selected: selectedBreed == r.value,
                onTap: () {
                  _answers['breed'] = r.value;
                  _handleUserResponse(r.value, displayText: r.label);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Full search button
        InkWell(
          onTap: species == null ? null : () => _showBreedPicker(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: ClovaraColors.forest.withOpacity(0.5), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    species == null ? 'Select dog/cat first' : 'Search all breeds...',
                    style: ClovaraTypography.body.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showBreedPicker() async {
    final species = (_answers['species'] as String?)?.toLowerCase();
    if (species == null || species.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select dog or cat first.')),
      );
      return;
    }

    final allBreeds = BreedCatalog.breedsForSpecies(species);
    final mixedBuckets = BreedCatalog.mixedBucketsForSpecies(species);
    final popular = BreedCatalog.popularBreedsForSpecies(species);

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? allBreeds
                : allBreeds.where((b) => b.toLowerCase().contains(q)).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.86,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Choose breed',
                          style: ClovaraTypography.h3.copyWith(
                            color: ClovaraColors.forest,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search breeds...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setModalState(() => query = v.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (q.isEmpty) ...[
                        _breedSection('Mixed / unknown', mixedBuckets),
                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        _breedSection('Popular', popular),
                        Divider(height: 1, color: Colors.grey.shade200),
                      ],
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final b = filtered[index];
                            return ListTile(
                              title: Text(
                                b,
                                style: ClovaraTypography.body.copyWith(
                                  color: ClovaraColors.forest,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => Navigator.pop(context, b),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    _handleUserResponse(selected, displayText: selected);
  }

  Widget _breedSection(String title, List<String> breeds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: ClovaraTypography.body.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breeds.map((b) {
              return InkWell(
                onTap: () => Navigator.pop(context, b),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: title == 'Popular'
                        ? const Color(0xFFF9FAF7)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: title == 'Popular'
                          ? ClovaraColors.forest.withOpacity(0.12)
                          : Colors.grey.shade300,
                      width: 1.1,
                    ),
                  ),
                  child: Text(
                    b,
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ---- Age picker (inline chips) ---------------------------------------

  Widget _buildAgePickerInline(QuestionData question) {
    final ageValue = _answers[question.field];
    final initialAge = ageValue is String
        ? int.tryParse(ageValue) ?? 3
        : (ageValue as num?)?.toInt() ?? 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HorizontalScrollPicker(
          min: 0,
          max: 20,
          step: 1,
          initialValue: initialAge.clamp(0, 20),
          unit: '',
          labelBuilder: (v) => v == 0 ? '<1' : '$v',
          onChanged: (_) {},
          onConfirm: (v) {
            final label = v == 0 ? '< 1 year' : '$v year${v == 1 ? '' : 's'}';
            _handleUserResponse(v, displayText: label);
          },
        ),
      ],
    );
  }

  // ---- Weight picker (inline scroll) -----------------------------------

  Widget _buildWeightPickerInline(QuestionData question) {
    final species = (_answers['species'] as String?)?.toLowerCase();
    final breed = _answers['breed'] as String?;
    final helper = _weightHelperText(species: species, breed: breed);

    final int weightMin;
    final int weightMax;
    final int weightStep;
    final int weightInitial;

    if (species == 'cat') {
      weightMin = 4;
      weightMax = 25;
      weightStep = 1;
      weightInitial = 10;
    } else {
      weightMin = 5;
      weightMax = 200;
      weightStep = 5;
      // Try to start near breed average
      final range = BreedSizeGuide.expectedAdultWeightLbs(breed);
      if (range != null) {
        final mid = ((range.minLbs + range.maxLbs) / 2).round();
        // Snap to nearest step
        weightInitial = (mid / weightStep).round() * weightStep;
      } else {
        weightInitial = 45;
      }
    }

    final existingWeight = _answers[question.field];
    final currentWeight = existingWeight is String
      ? int.tryParse(existingWeight)
      : (existingWeight as num?)?.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (helper != null) ...[
          Text(
            helper,
            style: ClovaraTypography.bodySmall.copyWith(
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ],
        _HorizontalScrollPicker(
          min: weightMin,
          max: weightMax,
          step: weightStep,
          initialValue: (currentWeight ?? weightInitial).clamp(weightMin, weightMax),
          unit: 'lbs',
          onChanged: (_) {},
          onConfirm: (v) {
            _handleUserResponse(v, displayText: '$v lbs');
          },
        ),
      ],
    );
  }

  String? _weightHelperText({String? species, String? breed}) {
    if (species == null) return 'Select dog or cat first';
    if (species == 'cat') return 'Most adult cats are 7-15 lbs';
    final range = BreedSizeGuide.expectedAdultWeightLbs(breed);
    if (range == null) return 'A rough estimate is fine.';
    return 'Typical range: ${range.minLbs.round()}-${range.maxLbs.round()} lbs';
  }

  // ---- Quick reply chips -----------------------------------------------

  Widget _buildQuickReplyChips(QuestionData question) {
    final replies = _getQuickRepliesForQuestion(question);
    if (replies.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return _OptionPill(
            label: reply.label,
            onTap: () =>
                _handleUserResponse(reply.value, displayText: reply.label),
          );
        }).toList(),
      ),
    );
  }

  // ---- Bottom input area -----------------------------------------------

  Widget _buildInputArea() {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 560;
    if (_currentQuestion >= _questions.length) return const SizedBox.shrink();
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
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 16 : 20,
        8,
        isNarrow ? 16 : 20,
        isNarrow ? 24 : 32,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isNarrow ? 24 : 28),
            border: Border.all(
              color: Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: question.placeholder ?? 'Type here\u2026',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 16 : 18,
                      vertical: isNarrow ? 16 : 14,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) _handleUserResponse(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ClovaraColors.clover.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Reusable pill / button widgets (private to this file)
// ---------------------------------------------------------------------------

class _OptionPill extends StatelessWidget {
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? ClovaraColors.forest.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? ClovaraColors.forest
                : Colors.black.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.06 : 0.03),
              blurRadius: selected ? 14 : 8,
              offset: Offset(0, selected ? 5 : 2),
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
                    ? ClovaraColors.forest
                    : ClovaraColors.forest.withOpacity(0.35),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [
                    ClovaraColors.clover,
                    ClovaraColors.clover.withOpacity(0.88),
                  ],
                )
              : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ClovaraColors.clover.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: ClovaraTypography.body.copyWith(
              color: enabled ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal scroll picker — ruler-style number selector
// ---------------------------------------------------------------------------

class _HorizontalScrollPicker extends StatefulWidget {
  final int min;
  final int max;
  final int step;
  final int initialValue;
  final String unit;
  final String Function(int)? labelBuilder;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onConfirm;

  const _HorizontalScrollPicker({
    required this.min,
    required this.max,
    this.step = 1,
    required this.initialValue,
    this.unit = '',
    this.labelBuilder,
    required this.onChanged,
    required this.onConfirm,
  });

  @override
  State<_HorizontalScrollPicker> createState() =>
      _HorizontalScrollPickerState();
}

class _HorizontalScrollPickerState extends State<_HorizontalScrollPicker> {
  late final FixedExtentScrollController _controller;
  late int _selectedValue;
  late final List<int> _values;

  static const double _itemWidth = 56.0;

  @override
  void initState() {
    super.initState();
    _values = [];
    for (int v = widget.min; v <= widget.max; v += widget.step) {
      _values.add(v);
    }
    _selectedValue = widget.initialValue.clamp(widget.min, widget.max);
    // Snap to nearest step
    final idx = _closestIndex(_selectedValue);
    _selectedValue = _values[idx];
    _controller = FixedExtentScrollController(initialItem: idx);
  }

  int _closestIndex(int value) {
    int best = 0;
    int bestDist = (value - _values[0]).abs();
    for (int i = 1; i < _values.length; i++) {
      final dist = (value - _values[i]).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(int v) =>
      widget.labelBuilder != null ? widget.labelBuilder!(v) : '$v';

  @override
  Widget build(BuildContext context) {
    final displayLabel = _label(_selectedValue);
    final displayUnit = widget.unit.isNotEmpty ? ' ${widget.unit}' : '';

    return Column(
      children: [
        // Current value display
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            '$displayLabel$displayUnit',
            key: ValueKey(_selectedValue),
            style: ClovaraTypography.h2.copyWith(
              color: ClovaraColors.forest,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Scroll picker
        SizedBox(
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The rotated list wheel (horizontal)
              RotatedBox(
                quarterTurns: -1,
                child: SizedBox(
                  width: 64,
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: _itemWidth,
                    diameterRatio: 6.0,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.002,
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedValue = _values[index]);
                      widget.onChanged(_values[index]);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _values.length,
                      builder: (context, index) {
                        final v = _values[index];
                        final isSelected = v == _selectedValue;
                        return RotatedBox(
                          quarterTurns: 1,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: isSelected ? 20 : 14,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? ClovaraColors.forest
                                    : ClovaraColors.forest.withOpacity(0.35),
                              ),
                              child: Text(_label(v)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Center highlight indicator
              IgnorePointer(
                child: Container(
                  width: _itemWidth,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: ClovaraColors.forest.withOpacity(0.15),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Swipe hint
        Text(
          '← swipe to adjust →',
          style: ClovaraTypography.bodySmall.copyWith(
            color: Colors.grey.shade500,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 16),

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: () => widget.onConfirm(_selectedValue),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: ClovaraColors.clover,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Confirm $displayLabel$displayUnit',
                  style: ClovaraTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

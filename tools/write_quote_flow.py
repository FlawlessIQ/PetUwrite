#!/usr/bin/env python3
"""Write the refactored conversational quote flow."""

import os

content = r'''import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../ai/clover_persona.dart';
import '../ai/clover_response_adapter.dart';
import '../data/breed_catalog.dart';
import '../data/breed_size_guide.dart';
import '../models/owner.dart';
import '../models/pet.dart';
import '../screens/ai_analysis_screen.dart';
import '../screens/customer_home_screen.dart';
import '../screens/login_screen.dart';
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
  const ConversationalQuoteFlow({super.key});

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

  // Confirmation flow
  bool _awaitingConfirmation = false;
  dynamic _pendingValue;
  String? _pendingField;

  // Services
  late ConversationalAIService _aiService;
  late CloverResponseAdapter _cloverAdapter;
  QuickCheckResult? _earlyEligibility;

  // Auth
  StreamSubscription<User?>? _authSubscription;

  // Autofocus tracking
  int _lastAutofocusQuestionIndex = -1;

  // Keys for scroll-into-view
  final GlobalKey _activeBotPromptKey = GlobalKey();
  final GlobalKey _activeInlineOptionsKey = GlobalKey();

  // ---- Questions (one-per-step) -----------------------------------------
  late final List<QuestionData> _questions = [
    // 0 — Owner name
    QuestionData(
      id: 'welcome',
      question: "Hi! I'm Clover — let's find the right plan for your pet. What's your name?",
      type: QuestionType.text,
      field: 'ownerName',
      placeholder: 'Your first name',
    ),
    // 1 — Pet name
    QuestionData(
      id: 'petName',
      question: "Nice to meet you, {ownerName}! What's your pet's name?",
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
      question: "Got it — and is {petName} male or female?",
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
    ),
    // 6 — Age
    QuestionData(
      id: 'age',
      question: "How old is {petName}?",
      type: QuestionType.agePicker,
      field: 'age',
    ),
    // 7 — Weight
    QuestionData(
      id: 'weight',
      question: "About how much does {petName} weigh?",
      type: QuestionType.weightPicker,
      field: 'weight',
    ),
    // 8 — Pre-existing conditions
    QuestionData(
      id: 'hasConditions',
      question: "Does {petName} have any pre-existing health conditions?",
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
      question: "No worries — lots of pets have them. Which conditions apply to {petName}?",
      type: QuestionType.multiSelect,
      field: 'preExistingConditionTypes',
      condition: (a) => a['hasPreExistingConditions'] == true,
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
      question: "Could you describe the other condition(s)?",
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
      question: "Is {petName} currently receiving treatment or medication for any of these?",
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
      question: "Almost done! What's a good email to send your quote to?",
      type: QuestionType.text,
      field: 'email',
      placeholder: 'you@email.com',
    ),
    // 13 — Zip code
    QuestionData(
      id: 'zipCode',
      question: "Last one — what's your zip code? (Pricing can vary by location.)",
      type: QuestionType.text,
      field: 'zipCode',
      placeholder: '10001',
    ),
  ];

  // ---- Lifecycle -------------------------------------------------------

  @override
  void initState() {
    super.initState();
    MarketingAttributionService.instance.captureCurrentAttribution();
    _aiService = ConversationalAIService();
    _cloverAdapter = CloverResponseAdapter();
    _setupAuthListener();
    _prefillUserData();
    _startConversation();
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
      await DraftService.save(answers: _answers, messages: []);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DraftService.saveToFirestore(
          uid: user.uid,
          answers: _answers,
          messages: [],
        );
      }
    } catch (e) {
      print('⚠️ Error saving pending quote: $e');
    }
  }

  Future<void> _copyResumeCode() async {
    await _savePendingQuote();
    if (!mounted) return;
    SaveResumeDialog.show(context, answers: _answers);
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
      if (profile != null) {
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

      final pending = await UserSessionService().getPendingQuote();
      if (pending != null && pending.isNotEmpty) {
        for (final entry in pending.entries) {
          _answers[entry.key] ??= entry.value;
        }
      }
    } catch (e) {
      print('⚠️ Error prefilling user data: $e');
    }
  }

  // ---- Conversation engine ---------------------------------------------

  Future<void> _startConversation() async {
    await Future.delayed(const Duration(milliseconds: 500));
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
      if (_answers.containsKey(q.field) && _answers[q.field] != null) {
        final val = _answers[q.field];
        if (val is String && val.isNotEmpty) {
          _currentQuestion++;
          continue;
        }
        if (val is! String) {
          _currentQuestion++;
          continue;
        }
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
    });

    // Generate question text — try AI first with a fast timeout
    String questionText = _formatQuestion(question.question);
    try {
      final context = _getQuestionContext(question);
      final aiResponse = await _aiService
          .generateBotResponse(
            questionId: question.id,
            previousAnswers: _answers,
            questionContext: context,
          )
          .timeout(const Duration(seconds: 2));

      if (aiResponse != null && aiResponse.trim().isNotEmpty) {
        questionText = _cloverAdapter.adaptResponse(
          aiResponse,
          context: context,
          petName: _answers['petName'] as String?,
        );
      }
    } catch (_) {
      // Use template text
    }

    // Stream the bot message
    await _streamBotMessage(questionText, question);

    if (!mounted) return;
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
    final totalUpdates = 28 + math.Random().nextInt(13);
    final charsPerTick = math.max(1, (text.length / totalUpdates).ceil());
    int shown = 0;
    while (shown < text.length) {
      shown = math.min(shown + charsPerTick, text.length);
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          text: text.substring(0, shown),
          isBot: true,
          timestamp: msg.timestamp,
          questionData: question,
        );
      });
      await Future.delayed(Duration(milliseconds: 12 + math.Random().nextInt(5)));
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
        _answers[_pendingField!] = _pendingValue;
        _awaitingConfirmation = false;
        _pendingField = null;
        _pendingValue = null;

        _addUserMessage(displayText ?? value.toString());
        _textController.clear();
        _currentQuestion++;
        await _tryUpdateUserProfile(_pendingField ?? '', _pendingValue);
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
        await Future.delayed(const Duration(milliseconds: 400));
        await _streamBotMessage(
          "No problem — let's try again.",
          _questions[_currentQuestion],
        );
        setState(() {
          _isTyping = false;
          _isWaitingForInput = true;
        });
        return;
      }
    }

    final question = _questions[_currentQuestion];

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
              field: question.field,
              userInput: value,
              context: _answers,
            )
            .timeout(const Duration(seconds: 3));
        if (validation != null && validation['needsConfirmation'] == true) {
          final corrected = validation['correctedValue'];
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

    // Handle conditions flow
    if (question.id == 'conditionTypes') {
      await _handleConditionSelection(value);
    } else if (question.id == 'hasConditions' && value == true) {
      // Empathetic transition to condition types
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Update user profile if applicable
    await _tryUpdateUserProfile(question.field, value);

    _currentQuestion++;

    setState(() => _isTyping = false);
    await Future.delayed(const Duration(milliseconds: 400));
    _showNextQuestion();
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
      } else if (field == 'email' && value is String && value.isNotEmpty) {
        await UserSessionService().updateUserProfile(email: value);
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
    if (conditions.isNotEmpty) {
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
          await _streamBotMessage(
            "One quick note: based on what you selected ($joined), we may not be able to offer a new policy for $petName. I'll still finish this up so we can confirm and share next steps.",
            _questions[_currentQuestion],
          );
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

  String _getQuestionContext(QuestionData question) {
    if (question.id == 'welcome' || question.id == 'petName') {
      return 'greeting';
    } else if (question.id.contains('condition') ||
        question.id.contains('health') ||
        question.id == 'hasConditions') {
      return 'health_conditions';
    } else if (question.id == 'email' || question.id == 'zipCode') {
      return 'completion';
    } else {
      return 'collecting_info';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
  //  BUILD
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    _scheduleAutofocusIfNeeded();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (_messages.isEmpty && !_isTyping) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: ClovaraColors.clover,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Clover is getting ready...',
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                      ),
                    ),
                  ],
                ),
              );
            }

            return MaxWidth(
              maxWidth: 680,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: 24,
                      ),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
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

  // ---- Header ----------------------------------------------------------

  Widget _buildHeader() {
    final answered = _messages.where((m) => !m.isBot).length;
    final total = _questions.where((q) => q.shouldShow(_answers)).length;
    final progress = total > 0 ? (answered / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ClovaraColors.forest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Home
              _headerIconButton(
                icon: Icons.home_outlined,
                tooltip: 'Back to website home',
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
                            child: const Text('Go to home'),
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
              // Bot avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: ClovaraColors.clover.withOpacity(0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(child: ClovaraMark(size: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CloverPersona.fullName,
                      style: ClovaraTypography.h3.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isTyping ? 'typing...' : 'Here to help',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: _isTyping
                            ? ClovaraColors.clover
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                    icon: snapshot.hasData ? Icons.account_circle : Icons.login,
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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.15),
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
      icon: Icon(icon, color: Colors.white, size: 22),
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  // ---- Typing indicator ------------------------------------------------

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _botAvatar(animate: true),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _buildDot(i)),
            ),
          ),
        ],
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
            color: ClovaraColors.forest.withOpacity(0.25 + animValue * 0.55),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  // ---- Message bubble --------------------------------------------------

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment:
            message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.isBot) ...[
            _botAvatar(),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(
                    message.isBot ? 8 * (1 - value) : -8 * (1 - value),
                    0,
                  ),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Column(
                crossAxisAlignment: message.isBot
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  _buildBubbleContent(message),
                  // Inline options for the active bot question
                  if (message.isBot &&
                      message.questionData != null &&
                      _isWaitingForInput &&
                      _messages.indexOf(message) == _messages.length - 1) ...[
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: _activeInlineOptionsKey,
                      child: _buildInlineOptions(message.questionData!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!message.isBot) ...[
            const SizedBox(width: 10),
            _userAvatar(),
          ] else
            const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessage message) {
    final isActiveBotPrompt = message.isBot &&
        message.questionData != null &&
        _isWaitingForInput &&
        _messages.indexOf(message) == _messages.length - 1;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.isBot ? Colors.white : ClovaraColors.forest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(message.isBot ? 6 : 20),
          bottomRight: Radius.circular(message.isBot ? 20 : 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.text,
        style: ClovaraTypography.body.copyWith(
          color: message.isBot ? ClovaraColors.forest : Colors.white,
          fontSize: 15,
          height: 1.45,
        ),
      ),
    );

    if (!isActiveBotPrompt) return bubble;
    return KeyedSubtree(key: _activeBotPromptKey, child: bubble);
  }

  // ---- Avatars ---------------------------------------------------------

  Widget _botAvatar({bool animate = false}) {
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(child: ClovaraMark(size: 22)),
    );

    if (!animate) return avatar;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.95, end: 1.0),
      builder: (_, value, child) {
        final pulse = 0.95 + 0.05 * (1 - (value * 2 - 1).abs());
        return Transform.scale(scale: pulse, child: child);
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
      child: avatar,
    );
  }

  Widget _userAvatar() {
    final ownerName = (_answers['ownerName'] as String?)?.trim();
    final initial = (ownerName != null && ownerName.isNotEmpty)
        ? ownerName.characters.first.toUpperCase()
        : null;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ClovaraColors.forest,
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: initial == null
            ? const Icon(Icons.person, color: Colors.white, size: 18)
            : Text(
                initial,
                style: ClovaraTypography.h3.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: question.options!.map((option) {
        return _OptionPill(
          label: option.label,
          icon: option.icon,
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
                onTap: () {
                  _answers['breed'] = r.value;
                  _autoFillWeightForBreed(r.value);
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
                color: ClovaraColors.clover.withOpacity(0.2),
                width: 1.4,
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

  void _autoFillWeightForBreed(String breed) {
    final range = BreedSizeGuide.expectedAdultWeightLbs(breed);
    if (range != null && !_answers.containsKey('weight')) {
      _answers['weight'] = ((range.minLbs + range.maxLbs) / 2).round();
    }
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
    _autoFillWeightForBreed(selected);
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
                        ? ClovaraColors.clover.withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: title == 'Popular'
                          ? ClovaraColors.clover.withOpacity(0.22)
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
    final replies = _getQuickRepliesForQuestion(question);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: replies.map((r) {
        return _OptionPill(
          label: r.label,
          onTap: () => _handleUserResponse(
            int.tryParse(r.value) ?? r.value,
            displayText: r.label,
          ),
        );
      }).toList(),
    );
  }

  // ---- Weight picker (inline chips + helper) ---------------------------

  Widget _buildWeightPickerInline(QuestionData question) {
    final species = (_answers['species'] as String?)?.toLowerCase();
    final breed = _answers['breed'] as String?;
    final replies = _getQuickRepliesForQuestion(question);
    final helper = _weightHelperText(species: species, breed: breed);

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: replies.map((r) {
            return _OptionPill(
              label: r.label,
              onTap: () => _handleUserResponse(
                int.tryParse(r.value) ?? r.value,
                displayText: r.label,
              ),
            );
          }).toList(),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  keyboardType: question.type == QuestionType.number
                      ? TextInputType.number
                      : TextInputType.text,
                  textCapitalization: TextCapitalization.words,
                  style: ClovaraTypography.body.copyWith(
                    color: ClovaraColors.forest,
                  ),
                  decoration: InputDecoration(
                    hintText: question.placeholder ?? 'Type your answer...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) _handleUserResponse(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: ClovaraColors.forest,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  if (_textController.text.isNotEmpty) {
                    _handleUserResponse(_textController.text);
                  }
                },
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? ClovaraColors.clover.withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? ClovaraColors.clover
                : ClovaraColors.clover.withOpacity(0.22),
            width: selected ? 1.6 : 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                selected ? Icons.check_circle : icon,
                size: 17,
                color: selected ? ClovaraColors.clover : ClovaraColors.forest.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: ClovaraTypography.body.copyWith(
                color: ClovaraColors.forest,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? ClovaraColors.clover : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
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
'''

path = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'lib', 'screens', 'conversational_quote_flow.dart',
)

with open(path, 'w') as f:
    f.write(content)

print(f'✅ Wrote {len(content)} chars to {path}')

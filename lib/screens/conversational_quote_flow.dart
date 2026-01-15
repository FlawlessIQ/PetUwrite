import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import '../theme/clovara_theme.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/pet.dart';
import '../models/owner.dart';
import '../services/risk_scoring_engine.dart';
import '../services/conversational_ai_service.dart';
import '../services/user_session_service.dart';
import '../services/draft_service.dart';
import '../services/underwriting_rules_engine.dart';
import '../services/breed_size_guide.dart';
import '../data/breed_catalog.dart';
import '../ai/ai_service.dart';
import '../ai/clover_persona.dart';
import '../ai/clover_response_adapter.dart';
import 'ai_analysis_screen_v2.dart';

/// Chatbot-style conversational quote flow with streaming text
class ConversationalQuoteFlow extends StatefulWidget {
  const ConversationalQuoteFlow({super.key});

  @override
  State<ConversationalQuoteFlow> createState() =>
      _ConversationalQuoteFlowState();
}

class _ConversationalQuoteFlowState extends State<ConversationalQuoteFlow>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final GlobalKey _activeInlineOptionsKey = GlobalKey();
  final GlobalKey _activeBotPromptKey = GlobalKey();

  int? _lastAutofocusQuestionIndex;

  int _currentQuestion = 0;
  final Map<String, dynamic> _answers = {};
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isWaitingForInput = false;
  Timer? _typingTimer;
  StreamSubscription<User?>? _authSubscription;

  // Confirmation state
  bool _awaitingConfirmation = false;
  String? _pendingValue;
  String? _pendingField;

  // AI service for natural conversations
  late ConversationalAIService _aiService;

  // Early underwriting signal (so we can message sooner on auto-declines)
  EligibilityResult? _earlyEligibility;

  // Clover personality adapter
  final CloverResponseAdapter _cloverAdapter = CloverResponseAdapter();

  // Question data
  final List<QuestionData> _questions = [
    QuestionData(
      id: 'welcome',
      question: "What's your name?",
      type: QuestionType.text,
      field: 'ownerName',
      placeholder: 'Your name',
      condition: (answers) =>
          answers['ownerName'] == null ||
          (answers['ownerName'] as String).isEmpty,
    ),
    QuestionData(
      id: 'petName',
      question: "Great to meet you, {ownerName}! What's your pet's name?",
      type: QuestionType.text,
      field: 'petName',
      placeholder: "Pet's name",
    ),
    QuestionData(
      id: 'petQuickDetails',
      question:
          "Perfect — let’s grab the basics for {petName}. This takes about 10 seconds.",
      type: QuestionType.petQuickDetails,
      field: 'petQuickDetails',
    ),
    // Conditional follow-up: Which conditions?
    QuestionData(
      id: 'conditionTypes',
      question: "Which health conditions does {petName} have?",
      type: QuestionType.multiSelect,
      field: 'preExistingConditionTypes',
      subtitle: "Select all that apply - we'll ask for more details next",
      condition: (answers) => answers['hasPreExistingConditions'] == true,
      options: [
        ChoiceOption(
          value: 'Allergies',
          label: 'Allergies',
          icon: Icons.local_hospital,
        ),
        ChoiceOption(
          value: 'Arthritis',
          label: 'Arthritis',
          icon: Icons.accessibility,
        ),
        ChoiceOption(
          value: 'Cancer (history)',
          label: 'Cancer (history)',
          icon: Icons.medical_services,
        ),
        ChoiceOption(
          value: 'Diabetes',
          label: 'Diabetes',
          icon: Icons.water_drop,
        ),
        ChoiceOption(
          value: 'Heart Disease',
          label: 'Heart Disease',
          icon: Icons.favorite,
        ),
        ChoiceOption(
          value: 'Hip Dysplasia',
          label: 'Hip Dysplasia',
          icon: Icons.elderly,
        ),
        ChoiceOption(
          value: 'Kidney Disease',
          label: 'Kidney Disease',
          icon: Icons.coronavirus,
        ),
        ChoiceOption(
          value: 'Skin Conditions',
          label: 'Skin Conditions',
          icon: Icons.healing,
        ),
        ChoiceOption(value: 'Other', label: 'Other', icon: Icons.more_horiz),
      ],
    ),

    // Conditional follow-up: capture the actual condition when 'Other' selected.
    QuestionData(
      id: 'conditionOtherText',
      question: "What condition should we list?",
      type: QuestionType.text,
      field: 'preExistingConditionOtherText',
      placeholder: 'e.g., Chronic ear infections, Seizures, GI issues',
      subtitle: 'This helps our underwriter review the right details',
      condition: (answers) {
        if (answers['hasPreExistingConditions'] != true) return false;
        final selected = answers['preExistingConditionTypes'];
        return selected is List && selected.contains('Other');
      },
    ),
    // Conditional follow-up: Currently being treated?
    QuestionData(
      id: 'conditionTreatment',
      question: "Are these conditions currently being treated?",
      type: QuestionType.choice,
      field: 'isReceivingTreatment',
      subtitle: "This includes medications, therapy, or regular vet visits",
      condition: (answers) => answers['hasPreExistingConditions'] == true,
      options: [
        ChoiceOption(
          value: true,
          label: 'Yes, actively treated',
          icon: Icons.medication,
        ),
        ChoiceOption(
          value: false,
          label: 'No, not currently treated',
          icon: Icons.cancel,
        ),
        ChoiceOption(
          value: 'managed',
          label: 'Managed/Stable',
          icon: Icons.check_circle_outline,
        ),
      ],
    ),
    QuestionData(
      id: 'email',
      question:
          "Great! What's your email address? We'll send your quote there.",
      type: QuestionType.text,
      field: 'email',
      placeholder: 'your@email.com',
    ),
    QuestionData(
      id: 'zipCode',
      question:
          "Finally, what's your zip code? This helps us calculate regional pricing.",
      type: QuestionType.text,
      field: 'zipCode',
      placeholder: 'e.g., 10001',
    ),
  ];

  @override
  void initState() {
    super.initState();
    print('🚀 ConversationalQuoteFlow: initState called');
    try {
      // AI runs via Firebase Functions proxy (no client-side keys).
      _aiService = ConversationalAIService();
      print('✅ ConversationalAIService initialized');

      // Set up auth state listener to save pending quotes
      _setupAuthListener();

      // Pre-fill user data if authenticated
      _prefillUserData();

      // Start the conversation
      _startConversation();
      print('✅ Conversation started');
    } catch (e, stackTrace) {
      print('❌ Error in initState: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Set up listener for auth state changes
  void _setupAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null &&
          _answers.isNotEmpty &&
          _currentQuestion > 0 &&
          _currentQuestion < _questions.length) {
        // User just signed in mid-quote - save their progress
        print('🔐 User signed in mid-quote - saving progress');
        _savePendingQuote();
      }
    });
  }

  /// Save current quote progress as pending
  Future<void> _savePendingQuote() async {
    if (_answers.isEmpty) return;

    try {
      print('💾 Saving pending quote at question $_currentQuestion');
      final quoteData = {
        'answers': _answers,
        'currentQuestion': _currentQuestion,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Save to local storage first
      await UserSessionService().savePendingQuote(quoteData);

      // Also persist a server-side draft under an anonymous session so users
      // can resume without explicit signup.
      try {
        await DraftService().upsertQuoteDraft(quoteData: quoteData);
      } catch (e) {
        // Do not block UX if server draft save fails.
        print('⚠️ Draft save failed (quote): $e');
      }

      // Also save to Firestore if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserSessionService().savePendingQuoteToFirestore(quoteData);
        print('✅ Pending quote saved to Firestore');
      }

      print('✅ Pending quote saved successfully');
    } catch (e) {
      print('⚠️ Error saving pending quote: $e');
    }
  }

  Future<void> _copyResumeCode() async {
    if (_answers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer a couple questions to get a resume code'),
        ),
      );
      return;
    }

    // Ensure there's a server-side draft saved for cross-device resume.
    await _savePendingQuote();

    try {
      final draftService = DraftService();
      final resumeKey = await draftService.getOrCreateLocalResumeKey();
      await Clipboard.setData(
        ClipboardData(text: draftService.encodeForSharing(resumeKey)),
      );

      if (!mounted) return;
      final pretty = draftService.prettyCode(resumeKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume code copied: $pretty')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy resume code')),
      );
    }
  }

  /// Pre-fill user data from authentication
  Future<void> _prefillUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('👤 No authenticated user - starting fresh quote');
      return;
    }

    print('👤 Authenticated user detected: ${user.email}');

    try {
      // Use UserSessionService to get user profile
      final userProfile = await UserSessionService().getUserProfile();
      print('📋 User profile fetched: ${userProfile.keys.toList()}');

      // Build full name from first and last name
      final firstName = userProfile['firstName'] as String?;
      final lastName = userProfile['lastName'] as String?;
      String? userName;

      if (firstName != null && firstName.isNotEmpty) {
        userName = lastName != null && lastName.isNotEmpty
            ? '$firstName $lastName'
            : firstName;
        print('✅ Found user name in profile: $userName');
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName;
        print('✅ Using Firebase Auth displayName: $userName');
      } else {
        // Extract name from email as last resort
        userName = user.email
            ?.split('@')
            .first
            .replaceAll('.', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
        print('⚠️ No profile name found, extracted from email: $userName');
      }

      // Pre-fill answers with user data
      if (userName != null && userName.isNotEmpty) {
        _answers['ownerName'] = userName;
        print('👋 Pre-filled owner name: $userName');
      } else {
        print('⚠️ No owner name could be determined');
      }

      if (user.email != null) {
        _answers['email'] = user.email!;
        print('📧 Pre-filled email: ${user.email}');
      }

      // Also get zip code if available
      final zipCode = userProfile['zipCode'] as String?;
      if (zipCode != null && zipCode.isNotEmpty) {
        _answers['zipCode'] = zipCode;
        print('📮 Pre-filled zip code: $zipCode');
      } else {
        print('⚠️ No zip code found in profile');
      }
    } catch (e) {
      print('❌ Error pre-filling user data: $e');
      // Still try to use email
      if (user.email != null) {
        _answers['email'] = user.email!;
        print('📧 Pre-filled email (fallback): ${user.email}');
      }
    }

    // Check for pending quote and restore it
    final pendingQuote = await UserSessionService().getPendingQuote();
    if (pendingQuote != null) {
      print('📋 Found pending quote - restoring progress');
      final savedAnswers = pendingQuote['answers'] as Map<String, dynamic>?;
      final savedQuestion = pendingQuote['currentQuestion'] as int?;

      if (savedAnswers != null) {
        _answers.addAll(savedAnswers);
        print('✅ Restored ${savedAnswers.length} answers');
      }

      if (savedQuestion != null && savedQuestion > 0) {
        _currentQuestion = savedQuestion;
        print('✅ Restored to question $_currentQuestion');
      }
    }
  }

  @override
  void dispose() {
    // Save pending quote before disposing (if user navigates away mid-quote)
    if (_answers.isNotEmpty &&
        _currentQuestion > 0 &&
        _currentQuestion < _questions.length) {
      print('🚪 Disposing widget with incomplete quote - saving progress');
      _savePendingQuote();
    }

    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _startConversation() async {
    print('💬 Starting conversation...');
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      print('⏱️ Delay complete, showing first question');
      _showNextQuestion();
    } catch (e, stackTrace) {
      print('❌ Error in _startConversation: $e');
      print('Stack: $stackTrace');
      // Fallback: show first question directly
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Hi! I'm Clover 🐾 Let's get started on finding the perfect insurance for your pet. What's your name?",
              isBot: true,
              timestamp: DateTime.now(),
              questionData: _questions[0],
            ),
          );
          _isTyping = false;
          _isWaitingForInput = true;
        });
      }
    }
  }

  void _showNextQuestion() async {
    print('❓ _showNextQuestion called, currentQuestion: $_currentQuestion');

    if (_currentQuestion >= _questions.length) {
      print('✅ All questions answered, completing quote');
      _completeQuote();
      return;
    }

    // Find next question that meets condition and isn't already answered
    while (_currentQuestion < _questions.length) {
      final question = _questions[_currentQuestion];
      final fieldName = question.field;

      // Skip questions that are already answered (pre-filled)
      if (_answers.containsKey(fieldName)) {
        final value = _answers[fieldName];
        if (value != null && value.toString().isNotEmpty) {
          print(
            '⏭️ Skipping pre-filled question $_currentQuestion: ${question.id} (${question.field} = $value)',
          );
          _currentQuestion++;
          continue;
        }
      }

      // Skip questions that don't meet their conditions
      if (!question.shouldShow(_answers)) {
        print(
          '⏭️ Skipping conditional question $_currentQuestion: ${question.id}',
        );
        _currentQuestion++;
        continue;
      }

      print('✓ Question $_currentQuestion should show: ${question.id}');
      break;
    }

    if (_currentQuestion >= _questions.length) {
      print('✅ No more questions, completing quote');
      _completeQuote();
      return;
    }

    final question = _questions[_currentQuestion];
    print('📝 Showing question: ${question.id}');

    // Show typing indicator
    if (mounted) {
      setState(() {
        _isTyping = true;
      });
    }
    _scrollToBottom(immediate: true);

    // Keep the UI snappy: the streaming effect already conveys "typing".
    final baseDelayMs = question.id == 'welcome' ? 250 : 180;
    await Future.delayed(Duration(milliseconds: baseDelayMs));

    // Generate AI-powered conversational question with Clover's personality
    String questionText;

    try {
      print('🤔 Generating question text for: ${question.id}');

      if (_currentQuestion > 0 && _messages.isNotEmpty) {
        final previousAnswer =
            _messages.where((m) => !m.isBot).lastOrNull?.text ?? '';
        final baseQuestion = _formatQuestion(question.question);

        // Critical perf optimization:
        // - Non-text questions and early deterministic questions should not
        //   incur network/AI latency.
        // - Web debug mode in particular suffers with network + streaming.
        final bool shouldUseAi =
            !kIsWeb &&
            question.type == QuestionType.text &&
            !{
              'welcome',
              'petName',
              'email',
            }.contains(question.id);

        if (!shouldUseAi) {
          questionText = _cloverAdapter.formatQuestion(
            baseQuestion,
            petName: _answers['petName'] as String?,
            context: _getQuestionContext(question),
            addTransition: _currentQuestion > 1,
          );
        } else {
          try {
            print('🤖 Calling AI service with timeout...');
            // Keep this short; a slow network should not block the quote flow.
            final aiResponse = await _aiService
                .generateBotResponse(
                  questionId: question.id,
                  baseQuestion: baseQuestion,
                  userAnswer: previousAnswer,
                  conversationContext: _answers,
                )
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    print('⏱️ AI service timed out, using fallback');
                    return baseQuestion;
                  },
                );

            final preview = aiResponse.length <= 50
                ? aiResponse
                : aiResponse.substring(0, 50);
            print('✅ AI response received: $preview...');

            questionText = _cloverAdapter.adaptResponse(
              aiResponse,
              context: _getQuestionContext(question),
              petName: _answers['petName'] as String?,
              userInput: previousAnswer,
              detectEmotions: true,
            );
          } catch (e) {
            print('⚠️ AI service error: $e, using fallback');
            questionText = _cloverAdapter.formatQuestion(
              baseQuestion,
              petName: _answers['petName'] as String?,
              context: _getQuestionContext(question),
              addTransition: _currentQuestion > 1,
            );
          }
        }
      } else {
        // First question or when we have no messages yet
        final isFirstMessage = _messages.isEmpty;
        final userName = _answers['ownerName'] as String?;

        if (isFirstMessage) {
          print('👋 Generating initial greeting...');

          // Personalize greeting if user is authenticated
          if (userName != null && userName.isNotEmpty) {
            // Extract first name for more natural greeting
            final firstName = userName.split(' ').first;

            // If the first question is the pet name (ownerName was skipped), include personalized greeting
            if (question.id == 'petName' || question.field == 'petName') {
              questionText =
                  "Welcome back, $firstName! 🐾 It's wonderful to see you again. Let's find the perfect insurance for your furry friend. What's your pet's name?";
              print('✅ Personalized greeting for returning user: $firstName');
            } else {
              // For any other first question with authenticated user
              final baseQuestion = _formatQuestion(question.question);
              questionText = "Welcome back, $firstName! 🐾 $baseQuestion";
              print(
                '✅ Personalized greeting for $firstName with question: ${question.id}',
              );
            }
          } else {
            // New user - combine Clover's greeting with the first question
            final greeting = CloverPersona.getRandomGreeting();
            final firstQuestion = _formatQuestion(question.question);
            questionText = '$greeting $firstQuestion';
            print('✅ New user greeting generated');
          }
        } else {
          // Not the first message - format question normally
          final baseQuestion = _formatQuestion(question.question);
          questionText = _cloverAdapter.formatQuestion(
            baseQuestion,
            petName: _answers['petName'] as String?,
            context: _getQuestionContext(question),
          );
        }
      }

      print('📤 Streaming message to UI...');
      // Add bot message with streaming effect
      await _streamBotMessage(questionText, question);

      print('✅ Message streamed successfully');

      if (mounted) {
        setState(() {
          _isTyping = false;
          _isWaitingForInput = true;
        });

        // Inline options can appear "below" the bot message bubble. The
        // streaming loop tends to pin the viewport to the very bottom,
        // which can land users halfway down a large panel.
        //
        // For quick-details specifically, we want the viewport anchored around
        // the bot prompt + last user reply, letting users scroll down into the
        // panel rather than jumping straight to (e.g.) Spayed/Neutered.
        if (_shouldAutoScrollToInlineOptions(question)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (question.type == QuestionType.petQuickDetails) {
              _scrollToKeyTop(_activeBotPromptKey, alignment: 0.90);
              return;
            }
            _scrollToKeyTop(_activeInlineOptionsKey, alignment: 0.10);
          });
        }
      }
      print('✅ Question display complete');
    } catch (e, stackTrace) {
      print('❌ Critical error in _showNextQuestion: $e');
      print('Stack: $stackTrace');

      // Emergency fallback - show simple question
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: _formatQuestion(question.question),
              isBot: true,
              timestamp: DateTime.now(),
              questionData: question,
            ),
          );
          _isTyping = false;
          _isWaitingForInput = true;
        });
      }
    }
  }

  Future<void> _streamBotMessage(String text, QuestionData question) async {
    final message = ChatMessage(
      text: '',
      isBot: true,
      timestamp: DateTime.now(),
      questionData: question,
    );

    setState(() {
      _messages.add(message);
    });

    // Stream text in throttled chunks to avoid hundreds of rebuilds/scroll
    // animations (which are especially slow on web).
    final total = text.length;
    if (total == 0) return;

    // Target a small number of UI updates (<= ~50) for smoothness.
    final targetUpdates = kIsWeb ? 28 : 40;
    final updates = total < targetUpdates ? total : targetUpdates;
    final chunkSize = (total / updates).ceil().clamp(1, total);
    final tickDelay = kIsWeb
        ? const Duration(milliseconds: 12)
        : const Duration(milliseconds: 16);

    int i = 0;
    int tick = 0;
    while (i < total) {
      await Future.delayed(tickDelay);
      if (!mounted) return;

      i = (i + chunkSize).clamp(0, total);
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          text: text.substring(0, i),
          isBot: true,
          timestamp: message.timestamp,
          questionData: question,
        );
      });

      // Keep the newest text visible without queuing tons of animations.
      if (tick % 4 == 0 || i == total) {
        _scrollToBottom(immediate: true);
      }
      tick++;
    }

    // One smooth settle at the end.
    _scrollToBottom();
  }

  bool _shouldAutoScrollToInlineOptions(QuestionData question) {
    return question.type == QuestionType.petQuickDetails ||
        question.type == QuestionType.choice ||
        question.type == QuestionType.multiSelect;
  }

  void _scrollToKeyTop(GlobalKey key, {double alignment = 0.0}) {
    if (!_scrollController.hasClients) return;
    final ctx = key.currentContext;
    if (ctx == null) return;

    final renderObject = ctx.findRenderObject();
    if (renderObject is RenderBox) {
      try {
        final viewport = RenderAbstractViewport.of(renderObject);
        final reveal = viewport.getOffsetToReveal(renderObject, alignment);
        final max = _scrollController.position.maxScrollExtent;
        final target = reveal.offset.clamp(0.0, max);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
        return;
      } catch (_) {
        // Fall through to ensureVisible.
      }
    }

    // Fallback: ensure visible (may not perfectly align if already partially visible).
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (immediate) {
          _scrollController.jumpTo(max);
          return;
        }
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleUserResponse(dynamic answer, {String? displayText}) async {
    final question = _questions[_currentQuestion];

    setState(() {
      _isWaitingForInput = false;
    });

    // Fast-path: quick pet details panel submits multiple fields at once.
    if (question.type == QuestionType.petQuickDetails) {
      final msgText = (displayText ?? '').trim().isNotEmpty
          ? displayText!.trim()
          : 'Done';

      setState(() {
        _messages.add(
          ChatMessage(text: msgText, isBot: false, timestamp: DateTime.now()),
        );
        _answers[question.field] = answer;
      });
      _scrollToBottom();

      await Future.delayed(const Duration(milliseconds: 400));
      _currentQuestion++;
      _showNextQuestion();
      return;
    }

    // Check if we're waiting for YES/NO confirmation
    if (_awaitingConfirmation && answer is String) {
      final answerLower = answer.toLowerCase().trim();

      if (answerLower == 'yes' || answerLower == 'y') {
        // User confirmed - accept the pending value
        print('✅ Confirmation accepted for $_pendingField: $_pendingValue');

        setState(() {
          _messages.add(
            ChatMessage(text: 'Yes', isBot: false, timestamp: DateTime.now()),
          );
          _answers[_pendingField!] = _pendingValue;
          _awaitingConfirmation = false;
          _pendingValue = null;
          _pendingField = null;
        });

        _scrollToBottom();
        _textController.clear();

        // Move to next question
        await Future.delayed(const Duration(milliseconds: 600));
        _currentQuestion++;
        _showNextQuestion();
        return;
      } else if (answerLower == 'no' || answerLower == 'n') {
        // User rejected - ask them to re-enter
        print('❌ Confirmation rejected - asking for new input');

        setState(() {
          _messages.add(
            ChatMessage(text: 'No', isBot: false, timestamp: DateTime.now()),
          );
          _awaitingConfirmation = false;
          _pendingValue = null;
          _pendingField = null;
        });

        _scrollToBottom();
        _textController.clear();

        // Re-ask the question
        await Future.delayed(const Duration(milliseconds: 600));
        await _streamBotMessage("No problem! ${question.question}", question);

        setState(() {
          _isWaitingForInput = true;
        });
        return;
      }
      // If they typed something else, treat it as a new answer and continue processing below
      setState(() {
        _awaitingConfirmation = false;
        _pendingValue = null;
        _pendingField = null;
      });
    }

    // For text/number/age inputs, validate and correct with AI
    if ((question.type == QuestionType.text ||
            question.type == QuestionType.number ||
            question.type == QuestionType.ageSlider) &&
        answer is String) {
      print('🤖 AI Validation - Question: ${question.id}, Input: "$answer"');

      String correctedAnswer = answer;
      bool needsConfirmation = false;
      String? message;
      bool isSerious = false;

      try {
        final validation = await _aiService.validateAndCorrectInput(
          questionId: question.id,
          userInput: answer,
          context: _answers,
        );

        print('✅ AI Validation Result: $validation');

        correctedAnswer = validation['corrected'] as String;
        needsConfirmation = validation['needsConfirmation'] as bool;
        message = validation['message'] as String?;
        isSerious = validation['isSerious'] as bool? ?? false;

        print(
          '📝 Corrected: "$correctedAnswer", NeedsConfirm: $needsConfirmation, Message: $message',
        );
      } catch (e) {
        print('❌ AI Validation Error: $e');
        // Fallback: use basic capitalization for text, or keep number as-is
        if (question.type == QuestionType.text) {
          correctedAnswer = answer
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              })
              .join(' ');
        } else {
          correctedAnswer = answer;
        }
      }

      // Add user message (show corrected version)
      setState(() {
        _messages.add(
          ChatMessage(
            text: displayText ?? correctedAnswer,
            isBot: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();
      _textController.clear();

      // Store corrected answer
      setState(() {
        _answers[question.field] = correctedAnswer;
      });

      // If AI generated a special message (empathetic or confirmation), show it
      if (message != null && message.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _streamBotMessage(message, question);
        // Give more time for empathetic messages
        final pauseDuration = isSerious ? 1200 : 600;
        await Future.delayed(Duration(milliseconds: pauseDuration));
      }

      // If needs confirmation, set confirmation state and wait for yes/no
      if (needsConfirmation) {
        setState(() {
          _awaitingConfirmation = true;
          _pendingValue = correctedAnswer;
          _pendingField = question.field;
          _isWaitingForInput = true;
        });
        return; // Stop here - wait for yes/no confirmation
      }
    } else {
      // For non-text inputs (choices, sliders), proceed as before
      setState(() {
        _answers[question.field] = answer;
      });

      setState(() {
        _messages.add(
          ChatMessage(
            text: displayText ?? answer.toString(),
            isBot: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();
      _textController.clear();

      // World-class UX: acknowledge health disclosures gently and (when possible)
      // give earlier underwriting guidance instead of surprising the user at the end.
      if (question.id == 'conditionTypes') {
        await _handleConditionSelection(answer);
      }
    }

    // Move to next question
    await Future.delayed(const Duration(milliseconds: 600));
    _currentQuestion++;
    _showNextQuestion();

    // Update user profile in background if we collected name or zipCode
    _updateUserProfileIfNeeded(question.field, answer);
  }

  // Old methods removed - using new chatbot flow

  /// Update user profile in background when key data is collected
  Future<void> _updateUserProfileIfNeeded(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Only update for authenticated users

    try {
      if (field == 'ownerName' && value is String && value.isNotEmpty) {
        // Split name into first and last
        final parts = value.trim().split(' ');
        final firstName = parts.first;
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

        await UserSessionService().updateUserProfile(
          firstName: firstName,
          lastName: lastName,
        );
        print('✅ Updated user profile with name: $firstName ${lastName ?? ""}');
      } else if (field == 'zipCode' && value is String && value.isNotEmpty) {
        await UserSessionService().updateUserProfile(zipCode: value);
        print('✅ Updated user profile with zipCode: $value');
      }
    } catch (e) {
      print('⚠️ Error updating user profile: $e');
      // Don't block the flow if profile update fails
    }
  }

  Future<void> _handleConditionSelection(dynamic answer) async {
    final petName = _answers['petName'] as String? ?? 'your pet';

    // Acknowledge health disclosures with a gentle tone.
    final conditions = answer is List
        ? answer.map((e) => e.toString()).toList()
        : <String>[];
    if (conditions.isNotEmpty) {
      final joined = conditions.length <= 2
          ? conditions.join(' and ')
          : '${conditions.take(2).join(', ')} and ${conditions.length - 2} more';

      await Future.delayed(const Duration(milliseconds: 400));
      await _streamBotMessage(
        "Thanks for sharing that about $petName. I know health stuff can be stressful — we'll take it step by step.",
        _questions[_currentQuestion],
      );
      await Future.delayed(const Duration(milliseconds: 600));

      // If the rules engine would auto-decline on critical conditions or excluded breeds,
      // tell the user sooner (without promising outcomes).
      try {
        final pet = _createPetFromAnswers();
        final quick = await UnderwritingRulesEngine().quickCheck(
          pet,
          conditions,
        );
        if (!quick.eligible) {
          _earlyEligibility = quick;
          await _streamBotMessage(
            "One quick note: based on what you selected ($joined), we may not be able to offer a new policy for $petName. I'll still finish this up so we can confirm and share next steps.",
            _questions[_currentQuestion],
          );
          await Future.delayed(const Duration(milliseconds: 900));
        }
      } catch (e) {
        // Non-blocking: this is just an early heads-up.
        print('⚠️ Early underwriting quickCheck failed: $e');
      }
    }
  }

  void _completeQuote() async {
    try {
      // Show Clover's celebration message
      final petName = _answers['petName'] as String? ?? 'your pet';

      setState(() {
        _isTyping = true;
        _isWaitingForInput = false;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      // Generate celebration message (avoid implying coverage is active)
      final celebrationMessage = _cloverAdapter.formatCelebration(
        petName: petName,
        achievement: "Let me calculate the best plan options for $petName.",
      );

      // Stream celebration message
      await _streamBotMessage(celebrationMessage, _questions.last);

      setState(() {
        _isTyping = false;
      });

      // Short pause to let user read the message
      await Future.delayed(const Duration(milliseconds: 1500));

      // Show analyzing message
      setState(() {
        _isTyping = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final analyzingMessage =
          "Reviewing $petName's details and generating your quote...";
      await _streamBotMessage(analyzingMessage, _questions.last);

      setState(() {
        _isTyping = false;
      });

      // Create Pet model from answers
      final pet = _createPetFromAnswers();

      print(
        '🩺 QuoteFlow preExistingConditions: ${pet.preExistingConditions.isEmpty ? '(none)' : pet.preExistingConditions.join(', ')}',
      );

      // Create Owner model from answers
      final owner = _createOwnerFromAnswers();

      // Initialize AI service and calculate risk score
      // Using Cloud Functions - no API key needed
      final aiService = GPTService();
      final riskEngine = RiskScoringEngine(aiService: aiService);

      // Calculate risk score WITH eligibility check
      final result = await riskEngine.calculateRiskScoreWithEligibility(
        pet: pet,
        owner: owner,
      );

      // Complex cases may require additional medical underwriting questions,
      // but should not require sign-in just to view a quote.
      final bool needsMedicalUnderwriting =
          pet.preExistingConditions.isNotEmpty ||
          (pet.isReceivingTreatment == true) ||
          result.hasExclusions;

      // Check if pet is eligible BEFORE showing plans
      // If we already detected a rules-based decline earlier, prefer that reason.
      final earlyDecline =
          _earlyEligibility != null && _earlyEligibility!.eligible == false;
      if ((!result.isEligible || earlyDecline) && mounted) {
        final declineReason = earlyDecline
            ? _earlyEligibility!.reason
            : (result.rejectionReason ??
                  'This application does not meet our current underwriting guidelines.');
        // Show decline dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: ClovaraColors.kWarmCoral),
                const SizedBox(width: 12),
                const Text('Application Declined'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thanks for sharing ${petName}\'s details. Based on what you told us, we can\'t offer a new policy right now.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(declineReason, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Text(
                  'If you think something is off or you\'d like to discuss alternatives, our underwriting team can help.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to home
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return; // Stop here - don't navigate to analysis screen
      }

      // Note: Underwriting case creation (and sign-in) should happen later in the
      // checkout path, not before a user can see their quote.

      // Pet is eligible - continue to analysis screen
      if (mounted) {
        // Clear pending quote since we're completing successfully
        await UserSessionService().clearPendingQuote();
        print('🗑️ Cleared pending quote');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIAnalysisScreen(
              pet: pet,
              riskScore: result.riskScore,
              routeArguments: {
                'petData': _answers,
                'pet': pet,
                'owner': owner,
                'riskScore': result.riskScore,
                'needsMedicalUnderwriting': needsMedicalUnderwriting,
                'hasExclusions': result.hasExclusions,
                'excludedConditions': result.excludedConditions,
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Risk calculation error: $e');

      // Get pet name for error message
      final petNameStr = _answers['petName'] as String? ?? 'your pet';

      // Show error dialog with better messaging
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: ClovaraColors.kWarmCoral,
                ),
                const SizedBox(width: 12),
                const Text('Unable to Calculate Risk'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We encountered an issue analyzing $petNameStr\'s profile, but we can still show you our available plans.',
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
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: ClovaraColors.clover,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Back'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Create Pet model from form answers
  Pet _createPetFromAnswers() {
    // Parse age - handle both String and int
    final ageValue = _answers['age'];
    final age = ageValue is String ? int.parse(ageValue) : ageValue as int;
    final dateOfBirth = DateTime.now().subtract(Duration(days: age * 365));

    // Convert weight from lbs to kg if needed
    final weightValue = _answers['weight'];
    final weight = weightValue is String
        ? double.parse(weightValue) *
              0.453592 // lbs to kg
        : (weightValue as num).toDouble() * 0.453592;

    // Get pre-existing conditions.
    // NOTE: We treat either the explicit boolean, selected types, or free-text
    // as a signal that medical underwriting is needed.
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

      // Replace 'Other' with the user-provided condition text when available.
      if (otherText.isNotEmpty) {
        if (conditions.isEmpty) {
          conditions = [otherText];
        } else {
          conditions = conditions
              .map((c) => c == 'Other' ? otherText : c)
              .toList();
          if (!conditions.contains(otherText) &&
              conditions.any((c) => c == 'Other')) {
            conditions.add(otherText);
          }
        }
      }

      // If we still don't have a specific condition, keep a generic marker.
      if (conditions.isEmpty) {
        conditions = ['Pre-existing condition reported'];
      }

      // Remove empty / placeholder strings.
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

  /// Create Owner model from form answers
  Owner _createOwnerFromAnswers() {
    final email = _answers['email'] as String;
    final zipCode = _answers['zipCode'] as String;

    // Extract name parts (owner name was collected first)
    final ownerName = _answers['ownerName'] as String;
    final nameParts = ownerName.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    // Extract state from zip code (simplified - would use real zip lookup)
    final state = _guessStateFromZipCode(zipCode);

    return Owner(
      id: 'owner_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: '', // Not collected yet
      address: Address(
        street: '', // Not collected yet
        city: '', // Would need zip code lookup
        state: state,
        zipCode: zipCode,
        country: 'USA',
      ),
    );
  }

  /// Guess state from zip code (simplified version)
  String _guessStateFromZipCode(String zipCode) {
    final zip = int.tryParse(zipCode) ?? 0;

    // Simplified state mapping by zip code ranges
    if (zip >= 10000 && zip <= 14999) return 'NY';
    if (zip >= 90000 && zip <= 96699) return 'CA';
    if (zip >= 60000 && zip <= 62999) return 'IL';
    if (zip >= 75000 && zip <= 79999) return 'TX';
    if (zip >= 30000 && zip <= 31999) return 'GA';
    if (zip >= 98000 && zip <= 99499) return 'WA';
    if (zip >= 85000 && zip <= 86599) return 'AZ';
    if (zip >= 33000 && zip <= 34999) return 'FL';
    if (zip >= 2000 && zip <= 2799) return 'MA';
    if (zip >= 19100 && zip <= 19699) return 'PA';

    return 'CA'; // Default fallback
  }

  String _formatQuestion(String question) {
    String formatted = question;
    _answers.forEach((key, value) {
      formatted = formatted.replaceAll('{$key}', value.toString());
    });
    return formatted;
  }

  /// Get the context for a question to guide Clover's tone
  String _getQuestionContext(QuestionData question) {
    if (question.id == 'welcome' || question.id == 'petName') {
      return 'greeting';
    } else if (question.id.contains('condition') ||
        question.id.contains('health')) {
      return 'health_conditions';
    } else if (question.id == 'email' || question.id == 'zipCode') {
      return 'completion';
    } else {
      return 'collecting_info';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building ConversationalQuoteFlow, messages: ${_messages.length}');

    _scheduleAutofocusIfNeeded();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            print(
              '📐 Layout constraints: ${constraints.maxWidth} x ${constraints.maxHeight}',
            );

            // Ensure minimum constraints for mobile
            final isMobile = constraints.maxWidth < 600;

            // Show loading state if no messages yet
            if (_messages.isEmpty && !_isTyping) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: ClovaraColors.clover),
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

            return Column(
              children: [
                // Header
                _buildChatHeader(),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 16 : 20,
                    ),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),

                // Input area
                if (_isWaitingForInput && _currentQuestion < _questions.length)
                  _buildInputArea(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _scheduleAutofocusIfNeeded() {
    if (!mounted) return;
    if (!_isWaitingForInput || _isTyping) return;
    if (_currentQuestion < 0 || _currentQuestion >= _questions.length) return;

    final question = _questions[_currentQuestion];
    if (question.type == QuestionType.choice ||
        question.type == QuestionType.multiSelect ||
        question.type == QuestionType.petQuickDetails) {
      return; // no text box on these
    }

    // If we're already focused for this prompt, do nothing.
    if (_focusNode.hasFocus &&
        _lastAutofocusQuestionIndex == _currentQuestion) {
      return;
    }

    // Avoid hammering focus requests every build; re-run when question changes
    // (or if focus was lost).
    _lastAutofocusQuestionIndex = _currentQuestion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isWaitingForInput || _isTyping) return;
      if (!_focusNode.canRequestFocus) return;

      // Put the cursor in the prompt box automatically.
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Widget _buildChatHeader() {
    final progress =
        _messages.where((m) => !m.isBot).length / _questions.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ClovaraColors.forest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Clover Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ClovaraColors.clover.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      'assets/images/clovara_mark_refined.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _isTyping ? 'typing...' : 'Here to help! 🐾',
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
                IconButton(
                  tooltip: 'Copy resume code',
                  onPressed: () {
                    unawaited(_copyResumeCode());
                  },
                  icon: const Icon(
                    Icons.content_copy,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              // Account button
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  return IconButton(
                    onPressed: () {
                      if (snapshot.hasData) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomerHomeScreen(isPremium: false),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      snapshot.hasData ? Icons.account_circle : Icons.login,
                      color: Colors.white,
                      size: 28,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(ClovaraColors.clover),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clover Avatar with pulse and glow animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              final pulse = 0.95 + (0.05 * (1 - (value * 2 - 1).abs()));
              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ClovaraColors.clover.withOpacity(
                          0.4 + (value * 0.2),
                        ),
                        blurRadius: 12 + (value * 8),
                        offset: const Offset(0, 2),
                        spreadRadius: value * 3,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(
                        'assets/images/clovara_mark_refined.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Typing dots with paw icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: 0.4 + (value * 0.6),
                      child: const Text('🐾', style: TextStyle(fontSize: 16)),
                    );
                  },
                  onEnd: () {
                    if (mounted) setState(() {}); // Loop animation
                  },
                ),
                const SizedBox(width: 8),
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
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
        final opacity = 0.3 + (animValue * 0.7);

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ClovaraColors.forest.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {}); // Loop animation
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) ...[
            // Clover Avatar with fade-in and slide animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(-10 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ClovaraColors.clover.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(6),
                            child: SvgPicture.asset(
                              'assets/images/clovara_mark_refined.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(
                    message.isBot ? 10 * (1 - value) : -10 * (1 - value),
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
                  Builder(
                    builder: (context) {
                      final isActiveBotPrompt =
                          message.isBot &&
                          message.questionData != null &&
                          _isWaitingForInput &&
                          _messages.indexOf(message) == _messages.length - 1;

                      final bubble = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: message.isBot
                              ? null
                              : ClovaraColors.brandGradient,
                          color: message.isBot ? Colors.white : null,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(message.isBot ? 4 : 20),
                            bottomRight: Radius.circular(
                              message.isBot ? 20 : 4,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message.text,
                          style: ClovaraTypography.body.copyWith(
                            color: message.isBot
                                ? ClovaraColors.forest
                                : Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      );

                      if (!isActiveBotPrompt) return bubble;
                      return KeyedSubtree(
                        key: _activeBotPromptKey,
                        child: bubble,
                      );
                    },
                  ),
                  // Show input options for current question
                  if (message.isBot &&
                      message.questionData != null &&
                      _isWaitingForInput &&
                      _messages.indexOf(message) == _messages.length - 1) ...[
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _activeInlineOptionsKey,
                      child: _buildInlineOptions(message.questionData!),
                    ),
                    if (message.questionData!.type == QuestionType.text ||
                        message.questionData!.type == QuestionType.number ||
                        message.questionData!.type ==
                            QuestionType.ageSlider) ...[
                      const SizedBox(height: 10),
                      _buildQuickReplyChips(message.questionData!),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Symmetry: bot messages have an avatar on the left; user messages
          // show an avatar on the right (instead of reserving unused space).
          if (!message.isBot) ...[
            const SizedBox(width: 10),
            _buildUserAvatar(),
          ] else ...[
            const SizedBox(width: 54),
          ],
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final ownerName = (_answers['ownerName'] as String?)?.trim();
    final initial = (ownerName != null && ownerName.isNotEmpty)
        ? ownerName.characters.first.toUpperCase()
        : null;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ClovaraColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.clover.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: initial == null
            ? const Icon(Icons.person, color: Colors.white, size: 22)
            : Text(
                initial,
                style: ClovaraTypography.h3.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _buildInlineOptions(QuestionData question) {
    if (question.type == QuestionType.petQuickDetails) {
      return _buildPetQuickDetailsPanel(question);
    }

    if (question.type == QuestionType.choice) {
      return _buildOptionCardsGrid(
        question.options!.map((option) {
          return InkWell(
            onTap: () =>
                _handleUserResponse(option.value, displayText: option.label),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ClovaraColors.clover.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(option.icon, color: ClovaraColors.clover, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else if (question.type == QuestionType.multiSelect) {
      // Multi-select for conditions - can select multiple options
      return _buildMultiSelectOptions(question);
    }
    return const SizedBox.shrink();
  }

  Widget _buildOptionCardsGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;

        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Prefer 2-up cards when we have enough room; fall back to 1 column on
        // narrow screens.
        final useTwoColumns = maxWidth >= 340;
        final columns = useTwoColumns ? 2 : 1;
        final itemWidth = columns == 1 ? maxWidth : (maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _buildPetQuickDetailsPanel(QuestionData question) {
    final petName = (_answers['petName'] as String?)?.trim();

    final species = (_answers['species'] as String?)?.toLowerCase();
    final gender = (_answers['gender'] as String?)?.toLowerCase();
    final breed = (_answers['breed'] as String?)?.trim();

    final ageRaw = _answers['age'];
    final ageYears = ageRaw is num
        ? ageRaw.toInt()
        : ageRaw is String
        ? int.tryParse(ageRaw)
        : null;

    final weightRaw = _answers['weight'];
    final weightLbs = weightRaw is num
        ? weightRaw.toDouble()
        : weightRaw is String
        ? double.tryParse(weightRaw)
        : null;

    final isNeutered = _answers['isNeutered'] as bool?;
    final hasConditions = _answers['hasPreExistingConditions'] as bool?;

    final bool isComplete =
        species != null &&
        species.isNotEmpty &&
        gender != null &&
        gender.isNotEmpty &&
        (breed != null && breed.isNotEmpty) &&
        ageYears != null &&
        weightLbs != null &&
        isNeutered != null &&
        hasConditions != null;

    final String petNameLabel = (petName == null || petName.isEmpty)
        ? 'your pet'
        : petName;

    final double weightMin = (species == 'cat') ? 4 : 5;
    final double weightMax = (species == 'cat') ? 25 : 200;
    final double weightDefault = (species == 'cat') ? 10 : 45;
    final double safeWeight = (weightLbs ?? weightDefault).clamp(
      weightMin,
      weightMax,
    );

    final int ageDefault = 3;
    final int safeAge = (ageYears ?? ageDefault).clamp(0, 20);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClovaraColors.clover.withOpacity(0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick details',
                  style: ClovaraTypography.h3.copyWith(
                    color: ClovaraColors.forest,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ClovaraColors.clover.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '10 sec',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap once for each choice — you can adjust anything before continuing.',
            style: ClovaraTypography.bodySmall.copyWith(
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final gap = isWide ? 14.0 : 12.0;
              final colWidth = isWide
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: colWidth,
                    child: _buildQuickBinaryGroup(
                      label: 'Pet',
                      options: const [
                        (value: 'dog', label: 'Dog', icon: Icons.pets),
                        (value: 'cat', label: 'Cat', icon: Icons.pets),
                      ],
                      selected: species,
                      onChanged: (v) {
                        setState(() {
                          _answers['species'] = v;

                          // Reset weight into a sensible range when species changes.
                          final newMin = (v == 'cat') ? 4 : 5;
                          final newMax = (v == 'cat') ? 25 : 200;
                          final currentWeight = _answers['weight'];
                          final current = currentWeight is num
                              ? currentWeight.toDouble()
                              : currentWeight is String
                              ? double.tryParse(currentWeight)
                              : null;
                          if (current == null ||
                              current < newMin ||
                              current > newMax) {
                            _answers['weight'] = (v == 'cat') ? 10 : 45;
                          }
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: colWidth,
                    child: _buildQuickBinaryGroup(
                      label: 'Sex',
                      options: const [
                        (value: 'male', label: 'Male', icon: Icons.male),
                        (value: 'female', label: 'Female', icon: Icons.female),
                      ],
                      selected: gender,
                      onChanged: (v) => setState(() => _answers['gender'] = v),
                    ),
                  ),
                  SizedBox(
                    width: colWidth,
                    child: _buildQuickBinaryGroupBool(
                      label: 'Spayed / Neutered',
                      leftLabel: 'Yes',
                      rightLabel: 'No',
                      selected: isNeutered,
                      onChanged: (v) =>
                          setState(() => _answers['isNeutered'] = v),
                    ),
                  ),
                  SizedBox(
                    width: colWidth,
                    child: _buildQuickBinaryGroupBool(
                      label: 'Pre-existing conditions',
                      leftLabel: 'None',
                      rightLabel: 'Yes',
                      invertLabels: true,
                      selected: hasConditions,
                      onChanged: (v) => setState(
                        () => _answers['hasPreExistingConditions'] = v,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          _buildBreedPickerRow(
            species: species,
            breed: breed,
            onPick: _showBreedPicker,
          ),

          const SizedBox(height: 14),

          _buildRangedPicker(
            label: 'Age',
            valueLabel: safeAge == 0 ? '< 1 year' : '$safeAge years',
            min: 0,
            max: 20,
            divisions: 20,
            value: safeAge.toDouble(),
            chips: const [
              (value: 0, label: '<1'),
              (value: 1, label: '1'),
              (value: 2, label: '2'),
              (value: 3, label: '3'),
              (value: 5, label: '5'),
              (value: 8, label: '8'),
              (value: 12, label: '12+'),
            ],
            onChanged: (v) => setState(() => _answers['age'] = v.round()),
          ),

          const SizedBox(height: 14),

          _buildRangedPicker(
            label: 'Weight',
            valueLabel: '${safeWeight.round()} lbs',
            min: weightMin,
            max: weightMax,
            divisions: (weightMax - weightMin).round(),
            value: safeWeight,
            chips: (species == 'cat')
                ? const [
                    (value: 7, label: '7'),
                    (value: 10, label: '10'),
                    (value: 12, label: '12'),
                    (value: 15, label: '15'),
                  ]
                : const [
                    (value: 15, label: '15'),
                    (value: 35, label: '35'),
                    (value: 65, label: '65'),
                    (value: 110, label: '110+'),
                  ],
            helperText: _weightHelperText(species: species, breed: breed),
            onChanged: species == null
                ? null
                : (v) => setState(() => _answers['weight'] = v.round()),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isComplete
                  ? () {
                      final summary = _formatQuickDetailsSummary(
                        petName: petNameLabel,
                        species: species,
                        breed: breed,
                        ageYears: safeAge,
                        weightLbs: safeWeight.round(),
                        gender: gender,
                        isNeutered: isNeutered,
                        hasConditions: hasConditions,
                      );

                      _handleUserResponse(true, displayText: summary);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClovaraColors.clover,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isComplete ? 'Continue' : 'Pick a few details to continue',
                    style: ClovaraTypography.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isComplete) ...[
            const SizedBox(height: 10),
            Text(
              'Required: dog/cat, breed, age, weight, sex, spayed/neutered, and conditions.',
              style: ClovaraTypography.bodySmall.copyWith(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _weightHelperText({
    required String? species,
    required String? breed,
  }) {
    if (species == null) return 'Select dog or cat first';
    if (species == 'cat') return 'Most adult cats are 7–15 lbs';

    final range = BreedSizeGuide.expectedAdultWeightLbs(breed);
    if (range == null) return 'A rough estimate is fine — we’ll adjust later.';
    return 'Typical adult range: ${range.minLbs.round()}–${range.maxLbs.round()} lbs';
  }

  String _formatQuickDetailsSummary({
    required String petName,
    required String? species,
    required String? breed,
    required int ageYears,
    required int weightLbs,
    required String? gender,
    required bool? isNeutered,
    required bool? hasConditions,
  }) {
    final parts = <String>[];
    if (species != null) {
      parts.add(species == 'cat' ? 'Cat' : 'Dog');
    }
    if (breed != null && breed.trim().isNotEmpty) parts.add(breed.trim());
    parts.add(ageYears == 0 ? '<1 yr' : '$ageYears yrs');
    parts.add('$weightLbs lbs');
    if (gender != null) parts.add(gender == 'female' ? 'Female' : 'Male');
    if (isNeutered != null)
      parts.add(isNeutered ? 'Spayed/Neutered' : 'Not spayed/neutered');
    if (hasConditions != null)
      parts.add(hasConditions ? 'Has conditions' : 'No conditions');
    return '$petName: ${parts.join(' • ')}';
  }

  Widget _buildBreedPickerRow({
    required String? species,
    required String? breed,
    required Future<void> Function() onPick,
  }) {
    final isSet = breed != null && breed.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breed',
          style: ClovaraTypography.body.copyWith(
            color: ClovaraColors.forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ClovaraColors.clover.withOpacity(0.20),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: ClovaraColors.forest.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSet
                        ? breed
                        : (species == null
                              ? 'Select dog/cat first'
                              : 'Search breeds…'),
                    style: ClovaraTypography.body.copyWith(
                      color: isSet
                          ? ClovaraColors.forest
                          : Colors.grey.shade700,
                      fontWeight: isSet ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade700),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select dog or cat first.')));
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
                : allBreeds
                      .where((b) => b.toLowerCase().contains(q))
                      .toList(growable: false);

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
                            hintText: 'Search breeds…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) =>
                              setModalState(() => query = v.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (q.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Mixed / unknown',
                            style: ClovaraTypography.body.copyWith(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: mixedBuckets.map((b) {
                              return InkWell(
                                onTap: () => Navigator.pop(context, b),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1.1,
                                    ),
                                  ),
                                  child: Text(
                                    b,
                                    style: ClovaraTypography.bodySmall.copyWith(
                                      color: ClovaraColors.forest,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Popular',
                            style: ClovaraTypography.body.copyWith(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: popular.map((b) {
                              return InkWell(
                                onTap: () => Navigator.pop(context, b),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ClovaraColors.clover.withOpacity(
                                      0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: ClovaraColors.clover.withOpacity(
                                        0.25,
                                      ),
                                      width: 1.25,
                                    ),
                                  ),
                                  child: Text(
                                    b,
                                    style: ClovaraTypography.bodySmall.copyWith(
                                      color: ClovaraColors.forest,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                              trailing: const Icon(Icons.chevron_right),
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

    if (!mounted) return;
    if (selected == null) return;

    setState(() {
      _answers['breed'] = selected;

      // If weight hasn't been set yet, gently auto-fill from a typical range.
      final weightExisting = _answers['weight'];
      final existing = weightExisting is num
          ? weightExisting.toDouble()
          : weightExisting is String
          ? double.tryParse(weightExisting)
          : null;
      if (existing == null) {
        final range = BreedSizeGuide.expectedAdultWeightLbs(selected);
        if (range != null) {
          _answers['weight'] = ((range.minLbs + range.maxLbs) / 2).round();
        }
      }
    });
  }

  Widget _buildRangedPicker({
    required String label,
    required String valueLabel,
    required double min,
    required double max,
    required int divisions,
    required double value,
    required List<({num value, String label})> chips,
    required void Function(double)? onChanged,
    String? helperText,
  }) {
    final disabled = onChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ClovaraTypography.body.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                valueLabel,
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: disabled ? 0.55 : 1,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ClovaraColors.clover,
              inactiveTrackColor: ClovaraColors.clover.withOpacity(0.15),
              thumbColor: ClovaraColors.clover,
              overlayColor: ClovaraColors.clover.withOpacity(0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips.map((c) {
              final v = c.value.toDouble();
              final selected = (value - v).abs() < 0.51;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: disabled ? null : () => onChanged(v),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ClovaraColors.clover.withOpacity(0.14)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? ClovaraColors.clover
                            : Colors.grey.shade300,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: ClovaraTypography.bodySmall.copyWith(
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickBinaryGroup({
    required String label,
    required List<({String value, String label, IconData icon})> options,
    required String? selected,
    required void Function(String value) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ClovaraTypography.body.copyWith(
            color: ClovaraColors.forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((o) {
                final isSelected = selected == o.value;
                return SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    onTap: () => onChanged(o.value),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ClovaraColors.clover.withOpacity(0.14)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? ClovaraColors.clover
                              : Colors.grey.shade300,
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            o.icon,
                            size: 18,
                            color: isSelected
                                ? ClovaraColors.clover
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              o.label,
                              style: ClovaraTypography.body.copyWith(
                                color: ClovaraColors.forest,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickBinaryGroupBool({
    required String label,
    required String leftLabel,
    required String rightLabel,
    required bool? selected,
    required void Function(bool value) onChanged,
    bool invertLabels = false,
  }) {
    // When invertLabels=true, left chip represents false and right represents true.
    final leftValue = invertLabels ? false : true;
    final rightValue = invertLabels ? true : false;

    return _buildQuickBinaryGroup(
      label: label,
      options: [
        (
          value: leftValue ? 'true' : 'false',
          label: leftLabel,
          icon: leftValue ? Icons.check_circle : Icons.cancel,
        ),
        (
          value: rightValue ? 'true' : 'false',
          label: rightLabel,
          icon: rightValue ? Icons.warning_rounded : Icons.cancel,
        ),
      ],
      selected: selected == null ? null : (selected ? 'true' : 'false'),
      onChanged: (v) => onChanged(v == 'true'),
    );
  }

  List<QuickReply> _getQuickRepliesForQuestion(QuestionData question) {
    final species = (_answers['species'] as String?)?.toLowerCase();
    final breed = _answers['breed'] as String?;

    switch (question.id) {
      case 'breed':
        if (species == 'cat') {
          return const [
            QuickReply(
              value: 'Domestic Shorthair',
              label: 'Domestic Shorthair',
            ),
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
          QuickReply(value: '0', label: '< 1'),
          QuickReply(value: '1', label: '1'),
          QuickReply(value: '2', label: '2'),
          QuickReply(value: '3', label: '3'),
          QuickReply(value: '5', label: '5'),
          QuickReply(value: '8', label: '8'),
          QuickReply(value: '12', label: '12+'),
        ];

      case 'weight':
        // Values are pounds.
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
            QuickReply(
              value: range.minLbs.round().toString(),
              label: '~${range.minLbs.round()} lbs',
            ),
            QuickReply(value: mid.toString(), label: '~$mid lbs'),
            QuickReply(
              value: range.maxLbs.round().toString(),
              label: '~${range.maxLbs.round()} lbs',
            ),
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

  Widget _buildQuickReplyChips(QuestionData question) {
    final replies = _getQuickRepliesForQuestion(question);
    if (replies.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return InkWell(
            onTap: () =>
                _handleUserResponse(reply.value, displayText: reply.label),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: ClovaraColors.clover.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Text(
                reply.label,
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMultiSelectOptions(QuestionData question) {
    // Track selected conditions in temporary state
    final selectedConditions = _answers[question.field] as List<String>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOptionCardsGrid(
          question.options!.map((option) {
            final isSelected = selectedConditions.contains(option.value);
            return InkWell(
              onTap: () {
                setState(() {
                  final updatedList = List<String>.from(selectedConditions);
                  if (isSelected) {
                    updatedList.remove(option.value);
                  } else {
                    updatedList.add(option.value as String);
                  }
                  _answers[question.field] = updatedList;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ClovaraColors.clover.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? ClovaraColors.clover
                        : ClovaraColors.clover.withOpacity(0.3),
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSelected ? ClovaraColors.clover : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      option.icon,
                      color: isSelected ? ClovaraColors.clover : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.label,
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Confirm button for multi-select
        Center(
          child: ElevatedButton(
            onPressed: selectedConditions.isNotEmpty
                ? () {
                    // Join condition names for display
                    final displayText = selectedConditions.length == 1
                        ? selectedConditions.first
                        : '${selectedConditions.length} conditions selected';
                    _handleUserResponse(
                      selectedConditions,
                      displayText: displayText,
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ClovaraColors.clover,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedConditions.isEmpty
                      ? 'Select at least one'
                      : 'Continue with ${selectedConditions.length} selected',
                  style: ClovaraTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    final question = _questions[_currentQuestion];

    if (question.type == QuestionType.choice ||
        question.type == QuestionType.multiSelect ||
        question.type == QuestionType.petQuickDetails) {
      return const SizedBox.shrink(); // Handled inline
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: Colors.grey.shade100,
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
                    if (value.isNotEmpty) {
                      _handleUserResponse(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: ClovaraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  if (_textController.text.isNotEmpty) {
                    _handleUserResponse(_textController.text);
                  }
                },
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data models for questions
enum QuestionType {
  text,
  number,
  choice,
  ageSlider,
  multiSelect,
  petQuickDetails,
}

class QuestionData {
  final String id;
  final String question;
  final QuestionType type;
  final String field;
  final String? placeholder;
  final String? suffix;
  final List<ChoiceOption>? options;
  final bool Function(Map<String, dynamic>)? condition; // Conditional display
  final String? subtitle; // Additional context

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

/// Chat message model for conversation UI
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

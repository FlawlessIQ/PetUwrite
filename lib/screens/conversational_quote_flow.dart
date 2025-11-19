import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../theme/clovara_theme.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/pet.dart';
import '../models/owner.dart';
import '../services/risk_scoring_engine.dart';
import '../services/conversational_ai_service.dart';
import '../services/user_session_service.dart';
import '../ai/ai_service.dart';
import '../ai/clover_persona.dart';
import '../ai/clover_response_adapter.dart';
import 'plan_selection_screen.dart';
import 'ai_analysis_screen_v2.dart';

/// Chatbot-style conversational quote flow with streaming text
class ConversationalQuoteFlow extends StatefulWidget {
  const ConversationalQuoteFlow({super.key});

  @override
  State<ConversationalQuoteFlow> createState() => _ConversationalQuoteFlowState();
}

class _ConversationalQuoteFlowState extends State<ConversationalQuoteFlow> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
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
      condition: (answers) => answers['ownerName'] == null || (answers['ownerName'] as String).isEmpty,
    ),
    QuestionData(
      id: 'petName',
      question: "Great to meet you, {ownerName}! What's your pet's name?",
      type: QuestionType.text,
      field: 'petName',
      placeholder: "Pet's name",
    ),
    QuestionData(
      id: 'species',
      question: "Tell me about {petName}. Are they a dog or cat?",
      type: QuestionType.choice,
      field: 'species',
      options: [
        ChoiceOption(value: 'dog', label: 'Dog', icon: Icons.pets),
        ChoiceOption(value: 'cat', label: 'Cat', icon: Icons.pets),
      ],
    ),
    QuestionData(
      id: 'breed',
      question: "What breed is {petName}?",
      type: QuestionType.text,
      field: 'breed',
      placeholder: 'e.g., Golden Retriever, Mixed Breed',
    ),
    QuestionData(
      id: 'age',
      question: "How old is {petName}?",
      type: QuestionType.ageSlider,
      field: 'age',
      placeholder: 'Select age',
    ),
    QuestionData(
      id: 'weight',
      question: "What's {petName}'s weight?",
      type: QuestionType.number,
      field: 'weight',
      placeholder: 'Weight in lbs',
      suffix: 'lbs',
    ),
    QuestionData(
      id: 'gender',
      question: "Is {petName} male or female?",
      type: QuestionType.choice,
      field: 'gender',
      options: [
        ChoiceOption(value: 'male', label: 'Male', icon: Icons.male),
        ChoiceOption(value: 'female', label: 'Female', icon: Icons.female),
      ],
    ),
    QuestionData(
      id: 'neutered',
      question: "Is {petName} spayed or neutered?",
      type: QuestionType.choice,
      field: 'isNeutered',
      options: [
        ChoiceOption(value: true, label: 'Yes', icon: Icons.check_circle),
        ChoiceOption(value: false, label: 'No', icon: Icons.cancel),
      ],
    ),
    QuestionData(
      id: 'preExisting',
      question: "Does {petName} have any pre-existing health conditions?",
      type: QuestionType.choice,
      field: 'hasPreExistingConditions',
      subtitle: "This helps us provide accurate coverage options",
      options: [
        ChoiceOption(value: false, label: 'No', icon: Icons.check_circle),
        ChoiceOption(value: true, label: 'Yes', icon: Icons.warning),
      ],
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
        ChoiceOption(value: 'Allergies', label: 'Allergies', icon: Icons.local_hospital),
        ChoiceOption(value: 'Arthritis', label: 'Arthritis', icon: Icons.accessibility),
        ChoiceOption(value: 'Cancer (history)', label: 'Cancer (history)', icon: Icons.medical_services),
        ChoiceOption(value: 'Diabetes', label: 'Diabetes', icon: Icons.water_drop),
        ChoiceOption(value: 'Heart Disease', label: 'Heart Disease', icon: Icons.favorite),
        ChoiceOption(value: 'Hip Dysplasia', label: 'Hip Dysplasia', icon: Icons.elderly),
        ChoiceOption(value: 'Kidney Disease', label: 'Kidney Disease', icon: Icons.coronavirus),
        ChoiceOption(value: 'Skin Conditions', label: 'Skin Conditions', icon: Icons.healing),
        ChoiceOption(value: 'Other', label: 'Other', icon: Icons.more_horiz),
      ],
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
        ChoiceOption(value: true, label: 'Yes, actively treated', icon: Icons.medication),
        ChoiceOption(value: false, label: 'No, not currently treated', icon: Icons.cancel),
        ChoiceOption(value: 'managed', label: 'Managed/Stable', icon: Icons.check_circle_outline),
      ],
    ),
    QuestionData(
      id: 'email',
      question: "Great! What's your email address? We'll send your quote there.",
      type: QuestionType.text,
      field: 'email',
      placeholder: 'your@email.com',
    ),
    QuestionData(
      id: 'zipCode',
      question: "Finally, what's your zip code? This helps us calculate regional pricing.",
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
      // Initialize AI service with API key from compile-time environment
      const apiKey = String.fromEnvironment('OPENAI_API_KEY');
      _aiService = ConversationalAIService(apiKey: apiKey.isEmpty ? null : apiKey);
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
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && _answers.isNotEmpty && _currentQuestion > 0 && _currentQuestion < _questions.length) {
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
        userName = lastName != null && lastName.isNotEmpty ? '$firstName $lastName' : firstName;
        print('✅ Found user name in profile: $userName');
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName;
        print('✅ Using Firebase Auth displayName: $userName');
      } else {
        // Extract name from email as last resort
        userName = user.email?.split('@').first.replaceAll('.', ' ').split(' ').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
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
    if (_answers.isNotEmpty && _currentQuestion > 0 && _currentQuestion < _questions.length) {
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
          _messages.add(ChatMessage(
            text: "Hi! I'm Clover 🐾 Let's get started on finding the perfect insurance for your pet. What's your name?",
            isBot: true,
            timestamp: DateTime.now(),
            questionData: _questions[0],
          ));
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
          print('⏭️ Skipping pre-filled question $_currentQuestion: ${question.id} (${question.field} = $value)');
          _currentQuestion++;
          continue;
        }
      }
      
      // Skip questions that don't meet their conditions
      if (!question.shouldShow(_answers)) {
        print('⏭️ Skipping conditional question $_currentQuestion: ${question.id}');
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
    _scrollToBottom();
    
    // Simulate typing delay
    await Future.delayed(Duration(milliseconds: 800 + (question.question.length * 8)));
    
    // Generate AI-powered conversational question with Clover's personality
    String questionText;
    
    try {
      print('🤔 Generating question text for: ${question.id}');
      
      if (_currentQuestion > 0 && _messages.isNotEmpty) {
        try {
          final previousAnswer = _messages.where((m) => !m.isBot).lastOrNull?.text ?? '';
          final baseQuestion = _formatQuestion(question.question);
          
          print('🤖 Calling AI service with timeout...');
          // Get AI response with timeout to prevent hanging
          final aiResponse = await _aiService.generateBotResponse(
            questionId: question.id,
            baseQuestion: baseQuestion,
            userAnswer: previousAnswer,
            conversationContext: _answers,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ AI service timed out, using fallback');
              return baseQuestion;
            },
          );
          
          print('✅ AI response received: ${aiResponse.substring(0, 50)}...');
          
          // Adapt with Clover's personality
          questionText = _cloverAdapter.adaptResponse(
            aiResponse,
            context: _getQuestionContext(question),
            petName: _answers['petName'] as String?,
            userInput: previousAnswer,
            detectEmotions: true,
          );
        } catch (e) {
          print('⚠️ AI service error: $e, using fallback');
          // Fallback to formatted base question with Clover formatting
          final baseQuestion = _formatQuestion(question.question);
          questionText = _cloverAdapter.formatQuestion(
            baseQuestion,
            petName: _answers['petName'] as String?,
            context: _getQuestionContext(question),
            addTransition: _currentQuestion > 1,
          );
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
              questionText = "Welcome back, $firstName! 🐾 It's wonderful to see you again. Let's find the perfect insurance for your furry friend. What's your pet's name?";
              print('✅ Personalized greeting for returning user: $firstName');
            } else {
              // For any other first question with authenticated user
              final baseQuestion = _formatQuestion(question.question);
              questionText = "Welcome back, $firstName! 🐾 $baseQuestion";
              print('✅ Personalized greeting for $firstName with question: ${question.id}');
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
      }
      print('✅ Question display complete');
    } catch (e, stackTrace) {
      print('❌ Critical error in _showNextQuestion: $e');
      print('Stack: $stackTrace');
      
      // Emergency fallback - show simple question
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: _formatQuestion(question.question),
            isBot: true,
            timestamp: DateTime.now(),
            questionData: question,
          ));
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
    
    // Stream text character by character
    for (int i = 0; i < text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          text: text.substring(0, i + 1),
          isBot: true,
          timestamp: message.timestamp,
          questionData: question,
        );
      });
      _scrollToBottom();
    }
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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
    
    // Check if we're waiting for YES/NO confirmation
    if (_awaitingConfirmation && answer is String) {
      final answerLower = answer.toLowerCase().trim();
      
      if (answerLower == 'yes' || answerLower == 'y') {
        // User confirmed - accept the pending value
        print('✅ Confirmation accepted for $_pendingField: $_pendingValue');
        
        setState(() {
          _messages.add(ChatMessage(
            text: 'Yes',
            isBot: false,
            timestamp: DateTime.now(),
          ));
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
          _messages.add(ChatMessage(
            text: 'No',
            isBot: false,
            timestamp: DateTime.now(),
          ));
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
         question.type == QuestionType.ageSlider) && answer is String) {
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
        
        print('📝 Corrected: "$correctedAnswer", NeedsConfirm: $needsConfirmation, Message: $message');
      } catch (e) {
        print('❌ AI Validation Error: $e');
        // Fallback: use basic capitalization for text, or keep number as-is
        if (question.type == QuestionType.text) {
          correctedAnswer = answer.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }).join(' ');
        } else {
          correctedAnswer = answer;
        }
      }
      
      // Add user message (show corrected version)
      setState(() {
        _messages.add(ChatMessage(
          text: displayText ?? correctedAnswer,
          isBot: false,
          timestamp: DateTime.now(),
        ));
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
        _messages.add(ChatMessage(
          text: displayText ?? answer.toString(),
          isBot: false,
          timestamp: DateTime.now(),
        ));
      });
      
      _scrollToBottom();
      _textController.clear();
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
        await UserSessionService().updateUserProfile(
          zipCode: value,
        );
        print('✅ Updated user profile with zipCode: $value');
      }
    } catch (e) {
      print('⚠️ Error updating user profile: $e');
      // Don't block the flow if profile update fails
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
      
      // Generate celebration message
      final celebrationMessage = _cloverAdapter.formatCelebration(
        petName: petName,
        achievement: "Let me calculate the best plans for $petName!",
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
      
      final analyzingMessage = "Analyzing $petName's profile and finding the pawfect coverage options... 🐾";
      await _streamBotMessage(analyzingMessage, _questions.last);
      
      setState(() {
        _isTyping = false;
      });
      
      // Create Pet model from answers
      final pet = _createPetFromAnswers();
      
      // Create Owner model from answers
      final owner = _createOwnerFromAnswers();
      
      // Initialize AI service and calculate risk score
      // Using Cloud Functions - no API key needed
      final aiService = GPTService(model: 'gpt-4o');
      final riskEngine = RiskScoringEngine(aiService: aiService);
      
      // Calculate risk score WITH eligibility check
      final result = await riskEngine.calculateRiskScoreWithEligibility(
        pet: pet,
        owner: owner,
      );
      
      // Check if pet is eligible BEFORE showing plans
      if (!result.isEligible && mounted) {
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
                  'Unfortunately, $petName does not qualify for coverage at this time.',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  result.rejectionReason ?? 'The application does not meet our current underwriting guidelines.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'If you have questions or believe this is an error, please contact our underwriting team.',
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
      
      // Check if there are EXCLUSIONS (conditional approval)
      if (result.hasExclusions && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: ClovaraColors.clover),
                const SizedBox(width: 12),
                const Text('Coverage Approved'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good news! $petName qualifies for coverage.',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'However, the following pre-existing conditions will be excluded from coverage:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...result.excludedConditions.map((condition) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.remove_circle_outline, 
                        size: 18, 
                        color: ClovaraColors.kWarmCoral),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          condition,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                Text(
                  'This means new conditions and accidents will be covered, but these existing conditions won\'t be.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                child: const Text('Continue to Plans'),
              ),
            ],
          ),
        );
      }
      
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
                  // Navigate to plans with null risk score
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlanSelectionScreen(),
                      settings: RouteSettings(arguments: {
                        'petData': _answers,
                        'riskScore': null,
                      }),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: ClovaraColors.clover,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Continue Anyway'),
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
        ? double.parse(weightValue) * 0.453592  // lbs to kg
        : (weightValue as num).toDouble() * 0.453592;
    
    // Get pre-existing conditions
    List<String> conditions = [];
    if (_answers['hasPreExistingConditions'] == true) {
      // Use the specific conditions if selected, otherwise generic
      final conditionTypes = _answers['preExistingConditionTypes'];
      if (conditionTypes != null && conditionTypes is List && conditionTypes.isNotEmpty) {
        conditions = List<String>.from(conditionTypes);
      } else {
        conditions = ['Pre-existing condition reported'];
      }
    }
    
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
    } else if (question.id.contains('condition') || question.id.contains('health')) {
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
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            print('📐 Layout constraints: ${constraints.maxWidth} x ${constraints.maxHeight}');
            
            // Ensure minimum constraints for mobile
            final isMobile = constraints.maxWidth < 600;
            
            // Show loading state if no messages yet
            if (_messages.isEmpty && !_isTyping) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: ClovaraColors.clover,
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

  Widget _buildChatHeader() {
    final progress = _messages.where((m) => !m.isBot).length / _questions.length;
    
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
                            builder: (context) => const CustomerHomeScreen(isPremium: false),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                        color: ClovaraColors.clover.withOpacity(0.4 + (value * 0.2)),
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
                      child: const Text(
                        '🐾',
                        style: TextStyle(fontSize: 16),
                      ),
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
        mainAxisAlignment: message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
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
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: message.isBot 
                    ? CrossAxisAlignment.start 
                    : CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: message.isBot
                          ? null
                          : ClovaraColors.brandGradient,
                      color: message.isBot ? Colors.white : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(message.isBot ? 4 : 20),
                        bottomRight: Radius.circular(message.isBot ? 20 : 4),
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
                  ),
                  // Show input options for current question
                  if (message.isBot && 
                      message.questionData != null && 
                      _isWaitingForInput &&
                      _messages.indexOf(message) == _messages.length - 1) ...[
                    const SizedBox(height: 12),
                    _buildInlineOptions(message.questionData!),
                  ],
                ],
              ),
            ),
          ),
          if (!message.isBot) 
            const SizedBox(width: 54)
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInlineOptions(QuestionData question) {
    if (question.type == QuestionType.choice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: question.options!.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _handleUserResponse(option.value, displayText: option.label),
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option.icon,
                      color: ClovaraColors.clover,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option.label,
                      style: ClovaraTypography.body.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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

  Widget _buildMultiSelectOptions(QuestionData question) {
    // Track selected conditions in temporary state
    final selectedConditions = _answers[question.field] as List<String>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...question.options!.map((option) {
          final isSelected = selectedConditions.contains(option.value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? ClovaraColors.clover.withOpacity(0.1) : Colors.white,
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
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
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
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
                    _handleUserResponse(selectedConditions, displayText: displayText);
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
    
    if (question.type == QuestionType.choice || question.type == QuestionType.multiSelect) {
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
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                    ),
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
enum QuestionType { text, number, choice, ageSlider, multiSelect }

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

  ChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
  });
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

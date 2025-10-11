import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../theme/petuwrite_theme.dart';
import '../auth/login_screen.dart';
import '../auth/customer_home_screen.dart';
import '../models/pet.dart';
import '../models/owner.dart';
import '../services/risk_scoring_engine.dart';
import '../services/conversational_ai_service.dart';
import '../ai/ai_service.dart';
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
  
  // AI service for natural conversations
  late ConversationalAIService _aiService;
  
  // Question data
  final List<QuestionData> _questions = [
    QuestionData(
      id: 'welcome',
      question: "Hi! I'm here to help you protect your furry friend. What's your name?",
      type: QuestionType.text,
      field: 'ownerName',
      placeholder: 'Your name',
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
    // Initialize AI service
    _aiService = ConversationalAIService();
    // Start the conversation
    _startConversation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }
  
  void _startConversation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _showNextQuestion();
  }
  
  void _showNextQuestion() async {
    if (_currentQuestion >= _questions.length) {
      _completeQuote();
      return;
    }
    
    // Find next question that meets condition
    while (_currentQuestion < _questions.length) {
      if (_questions[_currentQuestion].shouldShow(_answers)) {
        break;
      }
      _currentQuestion++;
    }
    
    if (_currentQuestion >= _questions.length) {
      _completeQuote();
      return;
    }
    
    final question = _questions[_currentQuestion];
    
    // Show typing indicator
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();
    
    // Simulate typing delay
    await Future.delayed(Duration(milliseconds: 800 + (question.question.length * 8)));
    
    // Generate AI-powered conversational question (if previous answer exists)
    String questionText;
    if (_currentQuestion > 0 && _messages.isNotEmpty) {
      try {
        final previousAnswer = _messages.where((m) => !m.isBot).lastOrNull?.text ?? '';
        questionText = await _aiService.generateBotResponse(
          questionId: question.id,
          baseQuestion: _formatQuestion(question.question),
          userAnswer: previousAnswer,
          conversationContext: _answers,
        );
      } catch (e) {
        // Fallback to formatted base question
        questionText = _formatQuestion(question.question);
      }
    } else {
      questionText = _formatQuestion(question.question);
    }
    
    // Add bot message with streaming effect
    await _streamBotMessage(questionText, question);
    
    setState(() {
      _isTyping = false;
      _isWaitingForInput = true;
    });
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
    
    // For text inputs, validate and correct with AI
    if (question.type == QuestionType.text && answer is String) {
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
        // Fallback: use basic capitalization
        correctedAnswer = answer.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
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
      
      // If needs confirmation, wait for user to confirm
      if (needsConfirmation) {
        // TODO: Add confirmation flow
        // For now, just proceed
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
  }
  
  // Old methods removed - using new chatbot flow

  void _completeQuote() async {
    try {
      // Create Pet model from answers
      final pet = _createPetFromAnswers();
      
      // Create Owner model from answers
      final owner = _createOwnerFromAnswers();
      
      // Initialize AI service and calculate risk score in background
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      final aiService = GPTService(apiKey: apiKey, model: 'gpt-4o');
      final riskEngine = RiskScoringEngine(aiService: aiService);
      
      // Start risk calculation (will complete during analysis screen animation)
      final riskScoreFuture = riskEngine.calculateRiskScore(
        pet: pet,
        owner: owner,
      );
      
      // Navigate to AI Analysis Screen immediately
      final riskScore = await riskScoreFuture;
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIAnalysisScreen(
              pet: pet,
              riskScore: riskScore,
              routeArguments: {
                'petData': _answers,
                'pet': pet,
                'owner': owner,
                'riskScore': riskScore,
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to calculate risk score: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildChatHeader(),
            
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    final progress = _messages.where((m) => !m.isBot).length / _questions.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: PetUwriteColors.kPrimaryNavy,
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
              // Bot Avatar - PetUwrite Logo
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: PetUwriteColors.kAccentSky.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/PetUwrite icon only.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PetUwrite Assistant',
                      style: PetUwriteTypography.h4.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _isTyping ? 'typing...' : 'Online',
                      style: PetUwriteTypography.caption.copyWith(
                        color: _isTyping 
                            ? PetUwriteColors.kSecondaryTeal 
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
              valueColor: AlwaysStoppedAnimation(PetUwriteColors.kSecondaryTeal),
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
          // AI Avatar with pulse animation
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
                        color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/ChatGPT Image Oct 10, 2025 at 04_07_17 PM.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to PetUwrite logo
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/PetUwrite icon only.png',
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Typing dots
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
            color: PetUwriteColors.kPrimaryNavy.withOpacity(opacity),
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
            // AI Avatar with fade-in animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
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
                            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/ChatGPT Image Oct 10, 2025 at 04_07_17 PM.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to PetUwrite logo
                            return Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/PetUwrite icon only.png',
                                fit: BoxFit.cover,
                              ),
                            );
                          },
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
                        : PetUwriteColors.brandGradient,
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
                    style: PetUwriteTypography.body.copyWith(
                      color: message.isBot 
                          ? PetUwriteColors.kPrimaryNavy 
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
          if (!message.isBot) const SizedBox(width: 54), // Space for avatar alignment
          if (message.isBot) const SizedBox(width: 40),
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
                    color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option.icon,
                      color: PetUwriteColors.kSecondaryTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option.label,
                      style: PetUwriteTypography.body.copyWith(
                        color: PetUwriteColors.kPrimaryNavy,
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
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputArea() {
    final question = _questions[_currentQuestion];
    
    if (question.type == QuestionType.choice) {
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
                  style: PetUwriteTypography.body.copyWith(
                    color: PetUwriteColors.kPrimaryNavy,
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
                gradient: PetUwriteColors.brandGradient,
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

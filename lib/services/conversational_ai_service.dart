import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../ai/ai_service.dart';

/// AI service for natural conversational interactions in quote flow
class ConversationalAIService {
  final GPTService _aiService;
  
  factory ConversationalAIService({String? apiKey}) {
    String key;
    
    // Priority 1: Use provided API key (for web deployment)
    if (apiKey != null && apiKey.isNotEmpty) {
      key = apiKey;
      print('✅ OpenAI API key provided directly');
      return ConversationalAIService._internal(key);
    }
    
    // Priority 2: Try loading from .env file (for local development)
    try {
      key = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (key.isNotEmpty) {
        print('✅ OpenAI API key loaded from .env file');
        return ConversationalAIService._internal(key);
      }
    } catch (e) {
      print('⚠️ Could not load .env file: $e');
    }
    
    // Priority 3: Fallback mode
    print('⚠️ OPENAI_API_KEY not found, conversations will use fallback responses');
    key = 'mock-key-for-fallback-mode';
    return ConversationalAIService._internal(key);
  }

  ConversationalAIService._internal(String apiKey) 
      : _aiService = GPTService(
          apiKey: apiKey,
          model: 'gpt-4o-mini', // Faster, cheaper for conversations
        );

  /// Generate an empathetic, contextual bot message based on user input
  Future<String> generateBotResponse({
    required String questionId,
    required String baseQuestion,
    required String userAnswer,
    required Map<String, dynamic> conversationContext,
  }) async {
    final prompt = _buildConversationalPrompt(
      questionId: questionId,
      baseQuestion: baseQuestion,
      userAnswer: userAnswer,
      context: conversationContext,
    );

    try {
      final response = await _aiService.generateText(prompt);
      return response.trim();
    } catch (e) {
      // Fallback to base question if AI fails
      return _personalizeBaseQuestion(baseQuestion, conversationContext);
    }
  }

  /// Validate and correct user input (breed names, capitalization, etc.)
  Future<Map<String, dynamic>> validateAndCorrectInput({
    required String questionId,
    required String userInput,
    required Map<String, dynamic> context,
  }) async {
    print('🔍 validateAndCorrectInput - QuestionID: "$questionId"');
    
    switch (questionId) {
      case 'welcome':  // Owner name question
      case 'ownerName':
      case 'petName':
        return {
          'corrected': _capitalizeNames(userInput),
          'needsConfirmation': false,
          'message': null,
        };

      case 'age':
        return _validateAge(userInput, context);

      case 'breed':
        return await _validateBreed(userInput, context);

      case 'preExistingConditionTypes':
        return await _validateHealthCondition(userInput, context);

      default:
        return {
          'corrected': userInput,
          'needsConfirmation': false,
          'message': null,
        };
    }
  }

  /// Generate empathetic response for health conditions
  Future<String> generateEmpatheticResponse({
    required String condition,
    required String petName,
  }) async {
    // USE MOCK MODE IF NO API KEY OR QUOTA EXCEEDED
    // Use real OpenAI API (or fallback responses if key missing)
    final prompt = '''
You are a compassionate pet insurance advisor. A pet owner just mentioned their pet has a health condition.

Pet's name: $petName
Condition mentioned: $condition

Generate a brief (1-2 sentences), warm, empathetic response that:
1. Acknowledges the condition with care and understanding
2. Reassures them that coverage is still possible
3. Uses the pet's name
4. Keeps a positive, supportive tone

Response:''';

    try {
      final response = await _aiService.generateText(prompt);
      return response.trim();
    } catch (e) {
      // Fallback empathetic message
      return "I'm sorry to hear $petName is dealing with that. We're here to help find the right coverage to support $petName's health journey.";
    }
  }

  /// Validate pet age input
  Map<String, dynamic> _validateAge(String input, Map<String, dynamic> context) {
    final species = context['species'] as String? ?? 'pet';
    final petName = context['petName'] as String? ?? 'your pet';
    
    print('🎂 Age Validation - Input: "$input", Species: $species');
    
    // Try to parse as integer
    final age = int.tryParse(input.trim());
    
    if (age == null) {
      return {
        'corrected': input,
        'needsConfirmation': true,
        'message': "I didn't quite catch that. How old is $petName in years? (Just enter a number)",
      };
    }
    
    // Age must be positive
    if (age < 0) {
      return {
        'corrected': input,
        'needsConfirmation': true,
        'message': "Hmm, age can't be negative! How old is $petName?",
      };
    }
    
    // Check for unrealistic ages
    // Dogs typically live 10-13 years (max recorded ~30)
    // Cats typically live 12-18 years (max recorded ~38)
    final maxAge = species == 'cat' ? 25 : 20;
    
    if (age > maxAge) {
      return {
        'corrected': input,
        'needsConfirmation': true,
        'message': "That seems unusually old for a $species! The typical maximum lifespan for ${species}s is around $maxAge years. Could you double-check $petName's age?",
      };
    }
    
    // Check for very young pets (under 2 months)
    if (age == 0) {
      return {
        'corrected': input,
        'needsConfirmation': true,
        'message': "Is $petName less than a year old? If so, could you tell me their age in months? (e.g., '6 months')",
      };
    }
    
    // Age is valid
    return {
      'corrected': age.toString(),
      'needsConfirmation': false,
      'message': null,
    };
  }

  /// Validate and correct dog/cat breed names
  Future<Map<String, dynamic>> _validateBreed(String input, Map<String, dynamic> context) async {
    final species = context['species'] as String?;
    
    print('🐕 Breed Validation - Input: "$input", Species: $species');
    
    // USE MOCK MODE IF NO API KEY OR QUOTA EXCEEDED
    // Use real OpenAI API (or fallback responses if key missing)
    final prompt = '''
The user entered a pet breed. Validate and correct it if needed.

Species: ${species ?? 'unknown'}
User input: "$input"

Task:
1. If it's a valid breed name, return it with proper capitalization
2. If it's misspelled, return the corrected breed name
3. If it's unclear or invalid, return null

Return ONLY the corrected breed name or "INVALID" if not a real breed.

Examples:
- "golden retriver" → "Golden Retriever"
- "labrador" → "Labrador Retriever"
- "lab" → "Labrador Retriever"
- "gsd" → "German Shepherd"
- "mut" → "Mixed Breed"
- "asdfgh" → "INVALID"

Corrected breed:''';

    try {
      print('📞 Calling OpenAI for breed validation...');
      final response = await _aiService.generateText(prompt);
      print('✅ OpenAI Response: "$response"');
      final corrected = response.trim();

      if (corrected == 'INVALID' || corrected.isEmpty) {
        return {
          'corrected': input,
          'needsConfirmation': true,
          'message': "Hmm, I didn't catch that breed. Mind spelling it out, or should we go with Mixed Breed?",
        };
      }

      // If correction was made, confirm with user
      if (corrected.toLowerCase() != input.toLowerCase()) {
        return {
          'corrected': corrected,
          'needsConfirmation': true,
          'message': "Just making sure - $corrected?",
        };
      }

      return {
        'corrected': corrected,
        'needsConfirmation': false,
        'message': null,
      };
    } catch (e, stackTrace) {
      // Fallback to basic capitalization
      print('❌ Breed Validation Error: $e');
      print('Stack trace: $stackTrace');
      return {
        'corrected': _capitalizeNames(input),
        'needsConfirmation': false,
        'message': null,
      };
    }
  }

  /// Validate and show empathy for health conditions
  Future<Map<String, dynamic>> _validateHealthCondition(String input, Map<String, dynamic> context) async {
    final petName = context['petName'] as String? ?? 'your pet';
    final lowerInput = input.toLowerCase();

    print('💊 Health Condition Validation - Input: "$input", Pet: $petName');

    // Check for serious conditions that need empathetic response
    final seriousConditions = [
      'cancer',
      'tumor',
      'leukemia',
      'lymphoma',
      'terminal',
      'dying',
      'critical',
      'emergency',
    ];

    final hasSeriousCondition = seriousConditions.any((condition) => 
      lowerInput.contains(condition)
    );

    print('❤️ Serious condition detected: $hasSeriousCondition');

    if (hasSeriousCondition) {
      print('📞 Generating empathetic response...');
      final empatheticMessage = await generateEmpatheticResponse(
        condition: input,
        petName: petName,
      );
      print('✅ Empathetic message: "$empatheticMessage"');

      return {
        'corrected': _capitalizeCondition(input),
        'needsConfirmation': false,
        'message': empatheticMessage,
        'isSerious': true,
      };
    }

    return {
      'corrected': _capitalizeCondition(input),
      'needsConfirmation': false,
      'message': "Thanks for letting me know about $petName's health history. This helps us find the right coverage.",
      'isSerious': false,
    };
  }

  /// Build conversational prompt for AI
  String _buildConversationalPrompt({
    required String questionId,
    required String baseQuestion,
    required String userAnswer,
    required Map<String, dynamic> context,
  }) {
    final petName = context['petName'] as String?;
    final ownerName = context['ownerName'] as String?;
    final now = DateTime.now();
    final currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return '''
You are Clover, a warm and friendly pet insurance advisor. You're having a natural, flowing conversation - not conducting an interview.

Current date: $currentDate

Context:
- Owner: ${ownerName ?? 'not provided yet'}
- Pet: ${petName ?? 'not provided yet'}
- They just said: "$userAnswer"
- Next topic: "$baseQuestion"

Guidelines:
1. VARY your responses - don't start every message the same way
2. Skip formulaic acknowledgments like "That's great to hear"
3. Ask the next question naturally, as if continuing a conversation
4. Use brief transitions: "Got it!", "Perfect,", "Awesome!", or jump right to the question
5. Keep it to 1 sentence when possible
6. Sound human - use contractions, be casual but professional
7. If the pet's name is mentioned, use it naturally (not in every message)
8. When dealing with dates, remember today is $currentDate

BAD examples:
❌ "That's great to hear, Conor! What breed is Freddy? I'd love to know more about him!"
❌ "I see. That's wonderful, Conor! How old is Freddy? I'm excited to hear more!"

GOOD examples:
✅ "What breed is Freddy?"
✅ "Got it! How old is he?"
✅ "Perfect. Is Freddy spayed or neutered?"
✅ "Awesome! Does Freddy have any pre-existing conditions I should know about?"

Your response (keep it natural and brief):''';
  }

  /// Personalize base question with context
  String _personalizeBaseQuestion(String baseQuestion, Map<String, dynamic> context) {
    var personalized = baseQuestion;
    
    // Replace placeholders
    if (context.containsKey('ownerName')) {
      personalized = personalized.replaceAll(
        '{ownerName}', 
        context['ownerName'] as String,
      );
    }
    
    if (context.containsKey('petName')) {
      personalized = personalized.replaceAll(
        '{petName}', 
        context['petName'] as String,
      );
    }

    return personalized;
  }

  /// Capitalize names properly
  String _capitalizeNames(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Capitalize medical conditions
  String _capitalizeCondition(String input) {
    // Keep acronyms uppercase, capitalize first letter of others
    final words = input.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;
      if (word.length <= 3 && word == word.toUpperCase()) {
        return word; // Keep acronyms like ACL, FIV
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Mock breed validation (when OpenAI API isn't available)
  Map<String, dynamic> _mockBreedValidation(String input, String? species) {
    print('🎭 Using MOCK breed validation');
    
    final lowerInput = input.toLowerCase().trim();
    
    // Common misspellings and abbreviations
    final breedCorrections = {
      'golden retriver': 'Golden Retriever',
      'golden retriever': 'Golden Retriever',
      'golden ritriver': 'Golden Retriever',
      'lab': 'Labrador Retriever',
      'labrador': 'Labrador Retriever',
      'gsd': 'German Shepherd',
      'german shepard': 'German Shepherd',
      'german shepherd': 'German Shepherd',
      'beagle': 'Beagle',
      'bulldog': 'Bulldog',
      'poodle': 'Poodle',
      'chihuahua': 'Chihuahua',
      'mut': 'Mixed Breed',
      'mutt': 'Mixed Breed',
      'mixed': 'Mixed Breed',
      'husky': 'Siberian Husky',
      'corgi': 'Welsh Corgi',
      'boxer': 'Boxer',
      'dachshund': 'Dachshund',
      'rottweiler': 'Rottweiler',
      'pitbull': 'American Pit Bull Terrier',
      'pit bull': 'American Pit Bull Terrier',
    };

    // Check if it's a known breed or correction
    if (breedCorrections.containsKey(lowerInput)) {
      final corrected = breedCorrections[lowerInput]!;
      
      // If it was corrected (not just capitalized), confirm with user
      if (corrected.toLowerCase() != lowerInput) {
        return {
          'corrected': corrected,
          'needsConfirmation': true,
          'message': "Just to confirm, you said $corrected, right?",
        };
      }
      
      return {
        'corrected': corrected,
        'needsConfirmation': false,
        'message': null,
      };
    }

    // If not in our list, just capitalize and accept
    return {
      'corrected': _capitalizeNames(input),
      'needsConfirmation': false,
      'message': null,
    };
  }

  /// Mock empathetic response (when OpenAI API isn't available)
  String _mockEmpatheticResponse(String condition, String petName) {
    print('🎭 Using MOCK empathetic response');
    
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('cancer')) {
      return "I'm so sorry to hear $petName is dealing with cancer. We're here to help find the right coverage to support $petName's health journey.";
    }
    
    if (lowerCondition.contains('tumor') || lowerCondition.contains('lymphoma')) {
      return "Thank you for sharing this about $petName. We understand how challenging this can be, and we're committed to finding coverage that can help.";
    }
    
    if (lowerCondition.contains('terminal') || lowerCondition.contains('critical')) {
      return "I appreciate you trusting us with this information about $petName. We're here to provide support and find the best options available.";
    }
    
    // Default empathetic response
    return "Thank you for letting me know about $petName's condition. We'll work to find coverage that can support their health needs.";
  }

  /// Parse date from natural language input
  Future<Map<String, dynamic>> parseDate(String input) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    
    final prompt = '''
Current date: $today (${DateFormat('EEEE, MMMM d, yyyy').format(now)})

Parse the following date input and return a date in ISO 8601 format (YYYY-MM-DD).

User input: "$input"

Return ONLY the date in format YYYY-MM-DD, nothing else. If the date cannot be parsed, return "ERROR".

Context for relative dates:
- Today is: $today
- Yesterday was: $yesterday

Examples:
- "yesterday" → $yesterday
- "today" → $today
- "last Monday" → (calculate last Monday from $today)
- "January 15, 2025" → 2025-01-15
- "01/15/2025" → 2025-01-15

Date:''';

    try {
      final response = await _aiService.generateText(prompt);
      final dateStr = response.trim();
      
      if (dateStr == 'ERROR' || dateStr.isEmpty) {
        return {'success': false};
      }
      
      // Validate it's a proper date
      DateTime.parse(dateStr);
      
      return {
        'success': true,
        'date': dateStr,
      };
    } catch (e) {
      return {'success': false};
    }
  }

  /// Analyze claim description for type, sentiment, and urgency
  Future<Map<String, dynamic>> analyzeClaimDescription(String description) async {
    final prompt = '''
Analyze this pet insurance claim description and classify it.

Description: "$description"

Provide a JSON response with:
1. claimType: "accident", "illness", or "wellness"
2. sentiment: "distressed", "worried", "calm", or "neutral"
3. urgency: "high", "normal", or "low"

Return ONLY valid JSON, no other text.

Example:
{"claimType": "accident", "sentiment": "worried", "urgency": "high"}

JSON:''';

    try {
      final response = await _aiService.generateText(prompt);
      final jsonStr = response.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Try to parse as JSON
      final Map<String, dynamic> result = {};
      
      // Simple parsing (you could use dart:convert for proper JSON)
      if (jsonStr.contains('accident')) {
        result['claimType'] = 'accident';
      } else if (jsonStr.contains('illness')) {
        result['claimType'] = 'illness';
      } else if (jsonStr.contains('wellness')) {
        result['claimType'] = 'wellness';
      } else {
        result['claimType'] = 'illness'; // default
      }
      
      if (jsonStr.contains('distressed')) {
        result['sentiment'] = 'distressed';
      } else if (jsonStr.contains('worried')) {
        result['sentiment'] = 'worried';
      } else if (jsonStr.contains('calm')) {
        result['sentiment'] = 'calm';
      } else {
        result['sentiment'] = 'neutral';
      }
      
      if (jsonStr.contains('"urgency":"high"') || jsonStr.contains('"urgency": "high"')) {
        result['urgency'] = 'high';
      } else if (jsonStr.contains('"urgency":"low"') || jsonStr.contains('"urgency": "low"')) {
        result['urgency'] = 'low';
      } else {
        result['urgency'] = 'normal';
      }
      
      return result;
    } catch (e) {
      // Default fallback
      return {
        'claimType': 'illness',
        'sentiment': 'neutral',
        'urgency': 'normal',
      };
    }
  }

  /// Parse currency amount from natural language
  Future<Map<String, dynamic>> parseCurrency(String input) async {
    final prompt = '''
Extract the dollar amount from this text and return ONLY the numeric value.

Text: "$input"

Return ONLY the number (e.g., 500.00), nothing else. If no amount found, return "ERROR".

Examples:
- "\$500" → 500.00
- "five hundred dollars" → 500.00
- "about 1,200" → 1200.00
- "around \$50" → 50.00

Amount:''';

    try {
      final response = await _aiService.generateText(prompt);
      final amountStr = response.trim().replaceAll('\$', '').replaceAll(',', '');
      
      if (amountStr == 'ERROR' || amountStr.isEmpty) {
        return {'success': false};
      }
      
      final amount = double.parse(amountStr);
      
      return {
        'success': true,
        'amount': amount,
      };
    } catch (e) {
      return {'success': false};
    }
  }
}

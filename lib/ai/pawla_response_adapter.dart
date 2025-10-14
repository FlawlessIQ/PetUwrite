/// Pawla Response Adapter
/// 
/// Wraps AI-generated responses with Pawla's personality,
/// adding empathy, conversational tone, and pet-friendly phrasing.
library;

import 'pawla_persona.dart';
import 'dart:math' as math;

class PawlaResponseAdapter {
  final math.Random _random = math.Random();
  
  /// Adapt a base AI response to match Pawla's personality
  String adaptResponse(
    String baseResponse, {
    String? context,
    String? petName,
    String? userInput,
    bool addPersonality = true,
    bool detectEmotions = true,
  }) {
    if (!addPersonality) {
      return baseResponse;
    }
    
    String adapted = baseResponse;
    
    // 1. Detect and respond to emotional content
    if (detectEmotions && userInput != null) {
      final emotionalResponse = PawlaPersona.getEmpatheticResponse(
        userInput,
        petName: petName,
      );
      
      if (emotionalResponse != null) {
        // Add empathetic preamble
        adapted = '$emotionalResponse\n\n$adapted';
      }
    }
    
    // 2. Add conversational warmth
    adapted = _addConversationalWarmth(adapted, petName: petName);
    
    // 3. Replace technical terms with friendly alternatives
    adapted = _softenTechnicalLanguage(adapted);
    
    // 4. Add pet puns occasionally (not too much!)
    if (_random.nextDouble() < 0.2) {
      adapted = _addPetPun(adapted);
    }
    
    // 5. Add encouraging phrases at appropriate points
    if (context == 'progress' && _random.nextDouble() < 0.4) {
      adapted += '\n\n${PawlaPersona.getRandomEncouragement()}';
    }
    
    // 6. Add rapport-building comments for pet names
    if (petName != null && 
        context == 'pet_introduction' && 
        _random.nextDouble() < 0.5) {
      adapted += '\n\n${PawlaPersona.getRandomRapportBuilder(petName)}';
    }
    
    return adapted;
  }
  
  /// Add conversational warmth to make responses feel more natural
  String _addConversationalWarmth(String response, {String? petName}) {
    // Add occasional conversational fillers at the start
    if (_random.nextDouble() < 0.15) {
      final filler = PawlaPersona.conversationalFillers[
        _random.nextInt(PawlaPersona.conversationalFillers.length)
      ];
      response = '${filler.substring(0, 1).toUpperCase()}${filler.substring(1)}, $response';
    }
    
    // Add acknowledgments before questions
    if (response.contains('?') && _random.nextDouble() < 0.2) {
      final acknowledgment = PawlaPersona.acknowledgments[
        _random.nextInt(PawlaPersona.acknowledgments.length)
      ];
      response = '$acknowledgment $response';
    }
    
    // Replace pet name tokens
    if (petName != null) {
      response = response.replaceAll('{petName}', petName);
    }
    
    return response;
  }
  
  /// Replace technical insurance jargon with friendly language
  String _softenTechnicalLanguage(String text) {
    final replacements = {
      'pre-existing condition': 'health condition that {petName} already has',
      'coverage': 'protection',
      'premium': 'monthly cost',
      'deductible': 'amount you pay before we help',
      'claim': 'request for help with vet bills',
      'underwriting': 'reviewing',
      'policy': 'plan',
      'policyholder': 'pet parent',
      'insured': 'protected',
      'exclusions': 'things not covered',
      'waiting period': 'time before coverage starts',
      'reimbursement': 'money back',
      'co-pay': 'your share',
      'annual limit': 'yearly maximum',
      'submit': 'send us',
      'documentation': 'paperwork',
      'veterinarian': 'vet',
    };
    
    String result = text;
    replacements.forEach((technical, friendly) {
      // Case-insensitive replacement
      final regex = RegExp(technical, caseSensitive: false);
      result = result.replaceAllMapped(regex, (match) {
        // Preserve original capitalization
        if (match.group(0)![0] == match.group(0)![0].toUpperCase()) {
          return friendly.substring(0, 1).toUpperCase() + friendly.substring(1);
        }
        return friendly;
      });
    });
    
    return result;
  }
  
  /// Occasionally add a pet pun for personality
  String _addPetPun(String text) {
    // Don't add puns to serious messages
    if (_isSerious(text)) {
      return text;
    }
    
    final punReplacements = {
      'important': 'im-paw-tant',
      'positive': 'paw-sitive',
      'awesome': 'paw-some',
      'perfect': 'pawfect',
      'forever': 'fur-ever',
      'fantastic': 'fur-tastic',
    };
    
    for (final entry in punReplacements.entries) {
      if (text.toLowerCase().contains(entry.key) && _random.nextDouble() < 0.3) {
        final regex = RegExp(entry.key, caseSensitive: false);
        text = text.replaceFirst(regex, entry.value);
        break; // Only one pun per message
      }
    }
    
    return text;
  }
  
  /// Check if the message is serious (avoid puns in serious contexts)
  bool _isSerious(String text) {
    final seriousKeywords = [
      'sorry',
      'unfortunately',
      'cannot',
      'denied',
      'illness',
      'disease',
      'cancer',
      'death',
      'died',
      'emergency',
      'serious',
      'condition',
      'diagnosis',
    ];
    
    final lowerText = text.toLowerCase();
    return seriousKeywords.any((keyword) => lowerText.contains(keyword));
  }
  
  /// Format a greeting with Pawla's personality
  String formatGreeting(String userName) {
    final greeting = PawlaPersona.getRandomGreeting();
    return greeting.replaceAll('Hi there!', 'Hi, $userName!');
  }
  
  /// Format a question with Pawla's conversational style
  String formatQuestion(
    String question, {
    String? petName,
    String? context,
    bool addTransition = false,
  }) {
    String formatted = question;
    
    // Replace pet name tokens
    if (petName != null) {
      formatted = formatted.replaceAll('{petName}', petName);
    }
    
    // Add transition phrase if requested
    if (addTransition && _random.nextDouble() < 0.5) {
      final transition = PawlaPersona.getRandomTransition();
      formatted = '$transition $formatted';
    }
    
    // Soften technical language
    formatted = _softenTechnicalLanguage(formatted);
    
    return formatted;
  }
  
  /// Format a confirmation message
  String formatConfirmation(String message, {String? petName}) {
    String formatted = message;
    
    // Add acknowledgment
    if (_random.nextDouble() < 0.6) {
      final acknowledgment = PawlaPersona.acknowledgments[
        _random.nextInt(PawlaPersona.acknowledgments.length)
      ];
      formatted = '$acknowledgment $formatted';
    }
    
    if (petName != null) {
      formatted = formatted.replaceAll('{petName}', petName);
    }
    
    return formatted;
  }
  
  /// Format an error or correction message (gentle and supportive)
  String formatCorrection(
    String correctedValue, {
    String? originalValue,
    String? explanation,
  }) {
    final intros = [
      "I think you meant",
      "Just to confirm, did you mean",
      "I want to make sure I got that right –",
      "Let me double-check –",
    ];
    
    final intro = intros[_random.nextInt(intros.length)];
    String message = '$intro "$correctedValue"';
    
    if (originalValue != null && originalValue != correctedValue) {
      message += ' (not "$originalValue")';
    }
    
    if (explanation != null) {
      message += '? $explanation';
    } else {
      message += '?';
    }
    
    return message;
  }
  
  /// Format a celebration message
  String formatCelebration({String? petName, String? achievement}) {
    String celebration = PawlaPersona.getRandomCelebration(petName: petName);
    
    if (achievement != null) {
      celebration += ' $achievement';
    }
    
    return celebration;
  }
  
  /// Generate an empathetic response for health-related topics
  String generateHealthResponse(
    String condition, {
    String? petName,
    String? followUpQuestion,
  }) {
    String response = PawlaPersona.getEmpatheticResponse(
      condition,
      petName: petName,
    ) ?? "I understand that ${petName ?? 'your pet'} has $condition.";
    
    if (followUpQuestion != null) {
      response += '\n\n$followUpQuestion';
    }
    
    return response;
  }
  
  /// Check if a user input contains emotional content
  bool detectsEmotion(String input) {
    return PawlaPersona.getEmpatheticResponse(input) != null;
  }
  
  /// Get the appropriate tone for a given context
  String getToneForContext(String context) {
    return PawlaPersona.getToneGuideline(context);
  }
  
  /// Generate a progress update message
  String generateProgressMessage(int current, int total, {String? petName}) {
    final percentage = (current / total * 100).round();
    
    String message;
    if (percentage < 25) {
      message = "Great start! We're just getting to know ${petName ?? 'your pet'}.";
    } else if (percentage < 50) {
      message = PawlaPersona.getRandomEncouragement();
    } else if (percentage < 75) {
      message = "You're more than halfway there! ${PawlaPersona.getRandomEncouragement()}";
    } else if (percentage < 100) {
      message = "Almost done! Just a couple more questions!";
    } else {
      message = PawlaPersona.getRandomCelebration(petName: petName);
    }
    
    return message;
  }
}

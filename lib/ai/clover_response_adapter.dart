/// Clover Response Adapter
/// 
/// Wraps AI-generated responses with Clover's personality,
/// adding clarity, conversational tone, and supportive phrasing.
library;

import 'clover_persona.dart';
import 'dart:math' as math;

class CloverResponseAdapter {
  final math.Random _random = math.Random();
  
  /// Adapt a base AI response to match Clover's personality
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
      final emotionalResponse = CloverPersona.getEmpatheticResponse(
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
    
    // 4. Add encouraging phrases at appropriate points
    if (context == 'progress' && _random.nextDouble() < 0.4) {
      adapted += '\n\n${CloverPersona.getRandomEncouragement()}';
    }
    
    // 5. Add rapport-building comments for pet names
    if (petName != null && 
        context == 'pet_introduction' && 
        _random.nextDouble() < 0.5) {
      adapted += '\n\n${CloverPersona.getRandomRapportBuilder(petName)}';
    }
    
    return adapted;
  }
  
  /// Add conversational warmth to make responses feel more natural
  String _addConversationalWarmth(String response, {String? petName}) {
    // Add occasional conversational fillers at the start
    if (_random.nextDouble() < 0.15) {
      final filler = CloverPersona.conversationalFillers[
        _random.nextInt(CloverPersona.conversationalFillers.length)
      ];
      response = '${filler.substring(0, 1).toUpperCase()}${filler.substring(1)}, $response';
    }
    
    // Add acknowledgments before questions
    if (response.contains('?') && _random.nextDouble() < 0.2) {
      final acknowledgment = CloverPersona.acknowledgments[
        _random.nextInt(CloverPersona.acknowledgments.length)
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
  
  /// Check if the message is serious
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
  
  /// Format a greeting with Clover's personality
  String formatGreeting(String userName) {
    final greeting = CloverPersona.getRandomGreeting();
    return greeting.replaceAll('Hi there!', 'Hi, $userName!');
  }
  
  /// Format a question with Clover's conversational style
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
      final transition = CloverPersona.getRandomTransition();
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
      final acknowledgment = CloverPersona.acknowledgments[
        _random.nextInt(CloverPersona.acknowledgments.length)
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
    String celebration = CloverPersona.getRandomCelebration(petName: petName);
    
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
    String response = CloverPersona.getEmpatheticResponse(
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
    return CloverPersona.getEmpatheticResponse(input) != null;
  }
  
  /// Get the appropriate tone for a given context
  String getToneForContext(String context) {
    return CloverPersona.getToneGuideline(context);
  }
  
  /// Generate a progress update message
  String generateProgressMessage(int current, int total, {String? petName}) {
    final percentage = (current / total * 100).round();
    
    String message;
    if (percentage < 25) {
      message = "Great start! We're just getting to know ${petName ?? 'your pet'}.";
    } else if (percentage < 50) {
      message = CloverPersona.getRandomEncouragement();
    } else if (percentage < 75) {
      message = "You're more than halfway there! ${CloverPersona.getRandomEncouragement()}";
    } else if (percentage < 100) {
      message = "Almost done! Just a couple more questions!";
    } else {
      message = CloverPersona.getRandomCelebration(petName: petName);
    }
    
    return message;
  }
}

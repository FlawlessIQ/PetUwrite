/// Conversation History Service
/// 
/// Manages persistent storage of conversation history for Pawla,
/// allowing users to resume conversations and providing context continuity.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationHistoryService {
  static const String _conversationKey = 'pawla_conversation_history';
  static const String _answersKey = 'pawla_conversation_answers';
  static const String _timestampKey = 'pawla_conversation_timestamp';
  
  /// Save conversation history
  Future<void> saveConversation({
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save messages
      final messagesJson = jsonEncode(messages);
      await prefs.setString(_conversationKey, messagesJson);
      
      // Save answers
      final answersJson = jsonEncode(answers);
      await prefs.setString(_answersKey, answersJson);
      
      // Save timestamp
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString(_timestampKey, timestamp);
    } catch (e) {
      print('Error saving conversation: $e');
    }
  }
  
  /// Load conversation history
  Future<Map<String, dynamic>?> loadConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final messagesJson = prefs.getString(_conversationKey);
      final answersJson = prefs.getString(_answersKey);
      final timestamp = prefs.getString(_timestampKey);
      
      if (messagesJson == null || answersJson == null) {
        return null;
      }
      
      // Check if conversation is stale (older than 24 hours)
      if (timestamp != null) {
        final savedTime = DateTime.parse(timestamp);
        final age = DateTime.now().difference(savedTime);
        
        if (age.inHours > 24) {
          // Clear stale conversation
          await clearConversation();
          return null;
        }
      }
      
      final messages = jsonDecode(messagesJson) as List<dynamic>;
      final answers = jsonDecode(answersJson) as Map<String, dynamic>;
      
      return {
        'messages': messages,
        'answers': answers,
        'timestamp': timestamp,
      };
    } catch (e) {
      print('Error loading conversation: $e');
      return null;
    }
  }
  
  /// Clear conversation history
  Future<void> clearConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationKey);
      await prefs.remove(_answersKey);
      await prefs.remove(_timestampKey);
    } catch (e) {
      print('Error clearing conversation: $e');
    }
  }
  
  /// Check if there's a saved conversation
  Future<bool> hasSavedConversation() async {
    final conversation = await loadConversation();
    return conversation != null;
  }
  
  /// Get the age of the saved conversation
  Future<Duration?> getConversationAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_timestampKey);
      
      if (timestamp == null) {
        return null;
      }
      
      final savedTime = DateTime.parse(timestamp);
      return DateTime.now().difference(savedTime);
    } catch (e) {
      print('Error getting conversation age: $e');
      return null;
    }
  }
  
  /// Export conversation as JSON (for debugging or analytics)
  Future<String?> exportConversation() async {
    final conversation = await loadConversation();
    if (conversation == null) {
      return null;
    }
    
    return jsonEncode({
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'conversation': conversation,
    });
  }
  
  /// Import conversation from JSON
  Future<bool> importConversation(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final conversation = data['conversation'] as Map<String, dynamic>;
      
      final messages = conversation['messages'] as List<dynamic>;
      final answers = conversation['answers'] as Map<String, dynamic>;
      
      await saveConversation(
        messages: messages.cast<Map<String, dynamic>>(),
        answers: answers,
      );
      
      return true;
    } catch (e) {
      print('Error importing conversation: $e');
      return false;
    }
  }
}

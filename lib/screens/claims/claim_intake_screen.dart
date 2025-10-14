import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/claim.dart';
import '../../services/claims_service.dart';
import '../../services/conversational_ai_service.dart';
import '../../theme/petuwrite_theme.dart';

/// Conversational AI-powered claim intake screen
/// Allows customers to file First Notice of Loss (FNOL) with empathy and guidance
class ClaimIntakeScreen extends StatefulWidget {
  final String policyId;
  final String petId;
  final String? draftClaimId; // Optional: for resuming existing drafts

  const ClaimIntakeScreen({
    super.key,
    required this.policyId,
    required this.petId,
    this.draftClaimId,
  });

  @override
  State<ClaimIntakeScreen> createState() => _ClaimIntakeScreenState();
}

class _ClaimIntakeScreenState extends State<ClaimIntakeScreen>
    with SingleTickerProviderStateMixin {
  final ConversationalAIService _aiService = ConversationalAIService();
  final ClaimsService _claimsService = ClaimsService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<ChatMessage> _messages = [];
  bool _isAITyping = false;
  bool _isSubmitting = false;

  // Collected claim data
  DateTime? _incidentDate;
  String? _description;
  ClaimType? _claimType;
  double? _estimatedCost;
  final List<String> _attachmentUrls = [];
  String? _draftClaimId;

  // Conversation stage tracking
  ClaimIntakeStage _currentStage = ClaimIntakeStage.greeting;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Initialize conversation with greeting or resume existing draft
  void _initializeConversation() async {
    print('DEBUG: Initializing conversation, draftClaimId: ${widget.draftClaimId}');
    
    bool draftLoaded = false;
    
    // Check if we're resuming an existing draft
    if (widget.draftClaimId != null) {
      print('DEBUG: Loading specific draft claim: ${widget.draftClaimId}');
      draftLoaded = await _loadExistingDraft();
    } else {
      // Check for any existing draft claims for this policy/pet
      print('DEBUG: Checking for existing drafts for policy: ${widget.policyId}, pet: ${widget.petId}');
      draftLoaded = await _checkForExistingDrafts();
    }
    
    // If no draft was loaded, start new conversation
    if (!draftLoaded) {
      print('DEBUG: No draft loaded, starting new conversation');
      _startNewConversation();
    }
  }

  /// Load existing draft claim data
  Future<bool> _loadExistingDraft() async {
    try {
      print('DEBUG: Attempting to load draft claim: ${widget.draftClaimId}');
      final claimDoc = await FirebaseFirestore.instance
          .collection('claims')
          .doc(widget.draftClaimId)
          .get();
      
      if (claimDoc.exists) {
        print('DEBUG: Draft claim document exists');
        final claimData = claimDoc.data()!;
        print('DEBUG: Claim data: $claimData');
        final claim = Claim.fromMap(claimData, claimDoc.id);
        
        // Populate the claim data
        _draftClaimId = claim.claimId;
        _incidentDate = claim.incidentDate;
        _description = claim.description;
        _claimType = claim.claimType;
        _estimatedCost = claim.claimAmount;
        _attachmentUrls.clear();
        _attachmentUrls.addAll(claim.attachments);
        
        print('DEBUG: Restoring conversation with draft data');
        // Restore conversation state with existing data
        _restoreConversationWithDraft(claim);
        return true;
      } else {
        print('DEBUG: Draft claim document does not exist');
        return false;
      }
    } catch (e) {
      print('ERROR loading existing draft: $e');
      // Fall back to new conversation
      return false;
    }
  }

  /// Check for existing draft claims for this policy/pet combination
  Future<bool> _checkForExistingDrafts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user');
        return false;
      }
      
      print('DEBUG: Querying for drafts - user: ${user.uid}, policy: ${widget.policyId}, pet: ${widget.petId}');
      final draftsQuery = await FirebaseFirestore.instance
          .collection('claims')
          .where('ownerId', isEqualTo: user.uid)
          .where('policyId', isEqualTo: widget.policyId)
          .where('petId', isEqualTo: widget.petId)
          .where('status', isEqualTo: 'draft')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      
      print('DEBUG: Found ${draftsQuery.docs.length} draft claims');
      
      if (draftsQuery.docs.isNotEmpty) {
        final draftDoc = draftsQuery.docs.first;
        final claimData = draftDoc.data();
        print('DEBUG: Loading draft: ${draftDoc.id}');
        final claim = Claim.fromMap(claimData, draftDoc.id);
        
        // Populate the claim data
        _draftClaimId = claim.claimId;
        _incidentDate = claim.incidentDate;
        _description = claim.description;
        _claimType = claim.claimType;
        _estimatedCost = claim.claimAmount;
        _attachmentUrls.clear();
        _attachmentUrls.addAll(claim.attachments);
        
        // Restore conversation state
        _restoreConversationWithDraft(claim);
        return true;
      }
      return false;
    } catch (e) {
      print('ERROR checking for existing drafts: $e');
      // Continue with new conversation
      return false;
    }
  }

  /// Restore conversation state with existing draft data
  void _restoreConversationWithDraft(Claim claim) {
    print('DEBUG: Restoring conversation with claim: ${claim.claimId}');
    print('DEBUG: Claim details - Date: ${claim.incidentDate}, Type: ${claim.claimType}, Desc: ${claim.description}, Amount: ${claim.claimAmount}');
    
    setState(() {
      _messages.clear();
      
      // Greeting message
      _messages.add(ChatMessage(
        text: "Hi there! I'm Pawla, and I can see you were working on a claim earlier. "
            "Let me help you continue where you left off. 🐾\n\n"
            "Here's what we have so far:",
        isUser: false,
        timestamp: DateTime.now(),
        showAvatar: true,
      ));

      // Show collected information
      final summaryText = _buildClaimSummary(claim);
      _messages.add(ChatMessage(
        text: summaryText,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      // Determine next step based on what's missing
      final nextStep = _determineNextStep(claim);
      _messages.add(ChatMessage(
        text: nextStep,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      
      _updateStageBasedOnProgress(claim);
      print('DEBUG: Restored ${_messages.length} messages, stage: $_currentStage');
    });
  }

  /// Start a new conversation for first-time claims
  void _startNewConversation() {
    setState(() {
      _messages.add(ChatMessage(
        text: "Hi there! I'm Pawla, and I'm here to help you file your claim. "
            "I know this might be a stressful time for you and your pet. "
            "Let's take this step by step together. 🐾\n\n"
            "First, can you tell me when the incident happened?",
        isUser: false,
        timestamp: DateTime.now(),
        showAvatar: true,
      ));
      _currentStage = ClaimIntakeStage.collectingDate;
    });
  }

  /// Build summary of existing claim data
  String _buildClaimSummary(Claim claim) {
    final buffer = StringBuffer();
    buffer.writeln("📋 **Claim Summary:**\n");
    
    buffer.writeln("📅 **Incident Date:** ${DateFormat('MMMM d, yyyy').format(claim.incidentDate)}");
    buffer.writeln("🏥 **Claim Type:** ${claim.claimType.displayName}");
    
    if (claim.description.isNotEmpty) {
      buffer.writeln("📝 **Description:** ${claim.description}");
    }
    
    if (claim.claimAmount > 0) {
      buffer.writeln("💰 **Estimated Cost:** \$${claim.claimAmount.toStringAsFixed(2)}");
    }
    
    if (claim.attachments.isNotEmpty) {
      buffer.writeln("📎 **Documents:** ${claim.attachments.length} file(s) uploaded");
    }
    
    return buffer.toString();
  }

  /// Determine what information is still needed
  String _determineNextStep(Claim claim) {
    if (claim.description.isEmpty) {
      return "Can you describe what happened in more detail?";
    } else if (claim.claimAmount <= 0) {
      return "Do you have an estimate of the veterinary costs? This helps us process your claim faster.";
    } else {
      return "Everything looks good! Would you like to add any documents (receipts, vet records, photos) or submit your claim?";
    }
  }

  /// Update conversation stage based on current progress
  void _updateStageBasedOnProgress(Claim claim) {
    if (claim.description.isEmpty) {
      _currentStage = ClaimIntakeStage.collectingDescription;
    } else if (claim.claimAmount <= 0) {
      _currentStage = ClaimIntakeStage.collectingCost;
    } else {
      _currentStage = ClaimIntakeStage.collectingDocuments;
    }
  }

  /// Handle user message
  Future<void> _handleUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isAITyping = true;
    });

    _scrollToBottom();

    // Process message based on current stage
    await _processMessageByStage(message);
  }

  /// Process message based on conversation stage
  Future<void> _processMessageByStage(String message) async {
    try {
      switch (_currentStage) {
        case ClaimIntakeStage.greeting:
          // Skip, already handled in init
          break;

        case ClaimIntakeStage.collectingDate:
          await _handleDateCollection(message);
          break;

        case ClaimIntakeStage.collectingDescription:
          await _handleDescriptionCollection(message);
          break;

        case ClaimIntakeStage.collectingCost:
          await _handleCostCollection(message);
          break;

        case ClaimIntakeStage.collectingDocuments:
          await _handleDocumentPrompt(message);
          break;

        case ClaimIntakeStage.aiAnalysis:
          await _handleAIAnalysis();
          break;

        case ClaimIntakeStage.confirmation:
          await _handleConfirmation(message);
          break;

        case ClaimIntakeStage.complete:
          _addAIMessage("Your claim has been submitted! Is there anything else I can help you with?");
          break;
      }
    } catch (e) {
      _addAIMessage("I'm sorry, I encountered an issue. Could you try rephrasing that?");
    } finally {
      setState(() {
        _isAITyping = false;
      });
      _scrollToBottom();
    }
  }

  /// Handle date collection with AI parsing
  Future<void> _handleDateCollection(String message) async {
    // Use AI to parse date from natural language
    final aiResponse = await _aiService.parseDate(message);
    
    if (aiResponse['success'] == true && aiResponse['date'] != null) {
      _incidentDate = DateTime.parse(aiResponse['date']);
      
      _addAIMessage(
        "Got it, the incident happened on ${DateFormat('MMMM d, yyyy').format(_incidentDate!)}. "
        "I'm so sorry to hear that. 💙\n\n"
        "Can you describe what happened? Take your time and include as many details as you'd like."
      );
      
      setState(() {
        _currentStage = ClaimIntakeStage.collectingDescription;
      });
    } else {
      _addAIMessage(
        "I'm having trouble understanding that date. Could you provide it in a format like "
        "'January 15, 2025' or '01/15/2025'?"
      );
    }
  }

  /// Handle description collection with AI sentiment analysis
  Future<void> _handleDescriptionCollection(String message) async {
    _description = message;

    // Use AI to classify claim type and detect sentiment
    final aiResponse = await _aiService.analyzeClaimDescription(message);
    
    _claimType = _parseClaimType(aiResponse['claimType']);
    final sentiment = aiResponse['sentiment'] ?? 'neutral';
    final urgency = aiResponse['urgency'] ?? 'normal';

    // Empathetic response based on sentiment
    String empathyMessage = _getEmpathyMessage(sentiment, urgency);

    _addAIMessage(
      "$empathyMessage\n\n"
      "Based on what you've shared, this looks like ${_claimType?.displayName.toLowerCase() ?? 'a claim'} claim. "
      "Do you happen to know the total cost or have an estimate? If not, that's okay - you can say 'not sure'."
    );

    setState(() {
      _currentStage = ClaimIntakeStage.collectingCost;
    });

    // Auto-save draft
    await _saveDraft();
  }

  /// Handle cost collection
  Future<void> _handleCostCollection(String message) async {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('not sure') || 
        lowerMessage.contains('don\'t know') ||
        lowerMessage.contains('unknown')) {
      _estimatedCost = null;
      _addAIMessage(
        "No problem at all! We can update that later.\n\n"
        "Would you like to upload any documents? This could be a vet invoice, receipt, "
        "or photos. You can upload them now or add them later."
      );
    } else {
      // Parse cost with AI
      final aiResponse = await _aiService.parseCurrency(message);
      if (aiResponse['success'] == true) {
        _estimatedCost = aiResponse['amount']?.toDouble();
        _addAIMessage(
          "Thank you! I've noted the estimated cost as ${_formatCurrency(_estimatedCost!)}.\n\n"
          "Would you like to upload any documents? This could be a vet invoice, receipt, "
          "or photos. You can upload them now or add them later."
        );
      } else {
        _addAIMessage(
          "I didn't quite catch that amount. Could you provide it like '\$500' or '500 dollars'? "
          "Or say 'not sure' if you don't have an estimate."
        );
        return;
      }
    }

    setState(() {
      _currentStage = ClaimIntakeStage.collectingDocuments;
    });

    await _saveDraft();
  }

  /// Handle document upload prompt
  Future<void> _handleDocumentPrompt(String message) async {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('yes') || lowerMessage.contains('upload')) {
      _addAIMessage("Great! Tap the 📎 button below to upload your documents.");
      // Don't advance stage - wait for actual upload
    } else if (lowerMessage.contains('later') || lowerMessage.contains('skip')) {
      await _proceedToAnalysis();
    } else {
      _addAIMessage(
        "Would you like to upload documents now, or would you prefer to do it later? "
        "Just say 'yes' to upload or 'later' to continue."
      );
    }
  }

  /// Proceed to AI analysis stage
  Future<void> _proceedToAnalysis() async {
    setState(() {
      _currentStage = ClaimIntakeStage.aiAnalysis;
      _isAITyping = true;
    });

    _addAIMessage(
      "Perfect! Let me review everything you've shared... 🤔"
    );

    await Future.delayed(const Duration(seconds: 2));

    await _handleAIAnalysis();
  }

  /// Handle AI analysis and summary
  Future<void> _handleAIAnalysis() async {
    // Generate AI summary and reasoning
    final summary = _generateClaimSummary();
    
    _addAIMessage(
      "Here's what I've gathered:\n\n"
      "$summary\n\n"
      "Does this look correct? Reply 'yes' to submit your claim, or let me know what needs to be changed."
    );

    setState(() {
      _currentStage = ClaimIntakeStage.confirmation;
      _isAITyping = false;
    });

    await _saveDraft();
  }

  /// Handle final confirmation
  Future<void> _handleConfirmation(String message) async {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('yes') || lowerMessage.contains('correct') || lowerMessage.contains('submit')) {
      await _submitClaim();
    } else {
      _addAIMessage(
        "No problem! What would you like to change? You can update:\n"
        "- The incident date\n"
        "- The description\n"
        "- The estimated cost\n"
        "- Or add/remove documents"
      );
      // Stay in confirmation stage for edits
    }
  }

  /// Submit final claim
  Future<void> _submitClaim() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create final claim
      final claim = Claim(
        claimId: _draftClaimId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        policyId: widget.policyId,
        ownerId: user.uid,
        petId: widget.petId,
        incidentDate: _incidentDate!,
        claimType: _claimType ?? ClaimType.illness,
        claimAmount: _estimatedCost ?? 0.0,
        description: _description ?? '',
        attachments: _attachmentUrls,
        status: ClaimStatus.submitted,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _claimsService.createClaim(claim);

      _addAIMessage(
        "✅ Your claim has been successfully submitted!\n\n"
        "Claim ID: ${claim.claimId}\n\n"
        "We'll review it and get back to you within 24-48 hours. "
        "You'll receive updates via email and in your policy dashboard.\n\n"
        "Is there anything else I can help you with today? 🐾"
      );

      setState(() {
        _currentStage = ClaimIntakeStage.complete;
      });
    } catch (e) {
      _addAIMessage(
        "I'm sorry, there was an issue submitting your claim. Please try again or contact support. "
        "Error: ${e.toString()}"
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Save draft claim to Firestore
  Future<void> _saveDraft() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final draftClaim = Claim(
        claimId: _draftClaimId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        policyId: widget.policyId,
        ownerId: user.uid,
        petId: widget.petId,
        incidentDate: _incidentDate ?? DateTime.now(),
        claimType: _claimType ?? ClaimType.illness,
        claimAmount: _estimatedCost ?? 0.0,
        description: _description ?? '',
        attachments: _attachmentUrls,
        status: ClaimStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _claimsService.saveDraftClaim(draftClaim);
      _draftClaimId = draftClaim.claimId;
    } catch (e) {
      print('Error saving draft: $e');
    }
  }

  /// Handle image/document upload
  Future<void> _handleImageUpload() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isAITyping = true;
        });

        // Upload to Firebase Storage
        final url = await _claimsService.uploadClaimDocument(
          image.path,
          _draftClaimId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );

        setState(() {
          _attachmentUrls.add(url);
        });

        _addAIMessage(
          "✅ Document uploaded successfully! You can upload more, or say 'done' when you're finished."
        );

        await _saveDraft();
      }
    } catch (e) {
      _addAIMessage("Sorry, there was an issue uploading that file. Could you try again?");
    } finally {
      setState(() {
        _isAITyping = false;
      });
    }
  }

  /// Generate claim summary for confirmation
  String _generateClaimSummary() {
    final buffer = StringBuffer();
    
    buffer.writeln("📅 Incident Date: ${_incidentDate != null ? DateFormat('MMMM d, yyyy').format(_incidentDate!) : 'Not provided'}");
    buffer.writeln("🏥 Claim Type: ${_claimType?.displayName ?? 'Unknown'}");
    buffer.writeln("💰 Estimated Cost: ${_estimatedCost != null ? _formatCurrency(_estimatedCost!) : 'Not provided'}");
    buffer.writeln("📝 Description: ${_description ?? 'Not provided'}");
    buffer.writeln("📎 Documents: ${_attachmentUrls.length} uploaded");
    
    return buffer.toString();
  }

  /// Get empathy message based on sentiment
  String _getEmpathyMessage(String sentiment, String urgency) {
    if (urgency == 'high') {
      return "I can tell this is urgent. Thank you for sharing those details with me.";
    }
    
    switch (sentiment) {
      case 'distressed':
        return "I can hear how difficult this must be for you. You're doing the right thing by getting help.";
      case 'worried':
        return "I understand your concern. Let's get this taken care of together.";
      case 'calm':
        return "Thank you for those details. You're handling this really well.";
      default:
        return "Thank you for sharing that with me.";
    }
  }

  /// Parse claim type from AI response
  ClaimType? _parseClaimType(String? type) {
    if (type == null) return null;
    try {
      return ClaimType.fromString(type);
    } catch (e) {
      return null;
    }
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  /// Add AI message to chat
  void _addAIMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        showAvatar: true,
      ));
    });
  }

  /// Scroll to bottom of chat
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/PetUwrite icon only.png'),
            ),
            const SizedBox(width: 8),
            const Text('File a Claim with Pawla'),
          ],
        ),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // AI typing indicator
            if (_isAITyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: const AssetImage('assets/PetUwrite icon only.png'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const _TypingIndicator(),
                    ),
                  ],
                ),
              ),

            // Input bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Attachment button
                  if (_currentStage == ClaimIntakeStage.collectingDocuments)
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _handleImageUpload,
                      tooltip: 'Upload document',
                    ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _handleUserMessage,
                      enabled: !_isAITyping && !_isSubmitting,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: PetUwriteColors.kSecondaryTeal,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isAITyping || _isSubmitting
                          ? null
                          : () => _handleUserMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build message bubble
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser && message.showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/PetUwrite icon only.png'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? PetUwriteColors.kSecondaryTeal
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool showAvatar;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.showAvatar = false,
  });
}

/// Claim intake conversation stages
enum ClaimIntakeStage {
  greeting,
  collectingDate,
  collectingDescription,
  collectingCost,
  collectingDocuments,
  aiAnalysis,
  confirmation,
  complete,
}

/// Animated typing indicator
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2);
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3 + opacity * 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

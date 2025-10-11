import '../models/claim.dart';
import '../widgets/pawla_avatar.dart';

/// Real-time claim tracker service
/// 
/// Generates contextual, empathetic status messages for Pawla
/// based on claim status, processing stage, and time elapsed
class ClaimTrackerService {
  /// Get current status message for Pawla
  static PawlaMessage getCurrentMessage(Claim claim) {
    final status = claim.status;
    final hasAI = claim.aiDecision != null;
    final elapsed = DateTime.now().difference(claim.updatedAt);
    
    if (status == ClaimStatus.settled) {
      return PawlaMessage(
        expression: PawlaExpression.celebrating,
        message: "🎉 Great news! Your claim has been approved and payment is on the way!",
        sentiment: MessageSentiment.positive,
      );
    }
    
    if (status == ClaimStatus.denied) {
      return PawlaMessage(
        expression: PawlaExpression.empathetic,
        message: "I know this isn't the news you hoped for. Let me explain why, and we can discuss next steps together.",
        sentiment: MessageSentiment.negative,
      );
    }
    
    if (status == ClaimStatus.processing) {
      // Different messages based on processing stage
      if (!hasAI) {
        if (claim.attachments.isEmpty) {
          return PawlaMessage(
            expression: PawlaExpression.thinking,
            message: "I'm ready to review your claim! Just upload your vet records and receipts to get started.",
            sentiment: MessageSentiment.neutral,
          );
        } else {
          return PawlaMessage(
            expression: PawlaExpression.working,
            message: _getDocumentReviewMessage(claim.attachments.length, elapsed),
            sentiment: MessageSentiment.neutral,
          );
        }
      } else {
        // AI analysis complete, waiting for human review
        final confidence = claim.aiConfidenceScore ?? 0.5;
        if (confidence >= 0.8) {
          return PawlaMessage(
            expression: PawlaExpression.happy,
            message: "Almost done! Your claim looks great. Just doing a final quality check...",
            sentiment: MessageSentiment.positive,
          );
        } else {
          return PawlaMessage(
            expression: PawlaExpression.thinking,
            message: "Our team is carefully reviewing your claim to make sure we get everything right for you.",
            sentiment: MessageSentiment.neutral,
          );
        }
      }
    }
    
    if (status == ClaimStatus.draft) {
      return PawlaMessage(
        expression: PawlaExpression.happy,
        message: "Hi! I'm Pawla, and I'm here to help you through the claims process. Let's get started!",
        sentiment: MessageSentiment.neutral,
      );
    }
    
    // Default fallback
    return PawlaMessage(
      expression: PawlaExpression.thinking,
      message: "I'm checking on your claim status. Hang tight!",
      sentiment: MessageSentiment.neutral,
    );
  }
  
  /// Get progress percentage (0-100)
  static int getProgressPercentage(Claim claim) {
    if (claim.status == ClaimStatus.settled || claim.status == ClaimStatus.denied) {
      return 100;
    }
    
    int progress = 0;
    
    // Step 1: Filed (20%)
    progress += 20;
    
    // Step 2: Documents uploaded (20%)
    if (claim.attachments.isNotEmpty) {
      progress += 20;
    }
    
    // Step 3: AI analysis complete (30%)
    if (claim.aiDecision != null) {
      progress += 30;
    }
    
    // Step 4: Human review if needed (30%)
    if (claim.humanOverride != null) {
      progress += 30;
    } else if (claim.aiConfidenceScore != null && claim.aiConfidenceScore! >= 0.8) {
      // High confidence, no human review needed
      progress += 15;
    }
    
    return progress.clamp(0, 95); // Never show 100% until truly complete
  }
  
  /// Get estimated time remaining
  static String getEstimatedTimeRemaining(Claim claim) {
    if (claim.status == ClaimStatus.settled || claim.status == ClaimStatus.denied) {
      return "Complete";
    }
    
    final hasAI = claim.aiDecision != null;
    final needsHuman = hasAI && (claim.aiConfidenceScore ?? 0) < 0.8;
    
    if (!hasAI) {
      if (claim.attachments.isEmpty) {
        return "Waiting for documents";
      }
      return "5-10 minutes"; // AI analysis time
    }
    
    if (needsHuman && claim.humanOverride == null) {
      return "1-2 hours"; // Human review time
    }
    
    return "A few minutes";
  }
  
  /// Get detailed status update messages
  static List<String> getDetailedUpdates(Claim claim) {
    final updates = <String>[];
    
    // Document review updates
    if (claim.attachments.isNotEmpty) {
      updates.add("✓ Received ${claim.attachments.length} document(s)");
      
      if (claim.aiDecision != null) {
        updates.add("✓ Documents verified and processed");
      } else {
        updates.add("⏳ Extracting information from your documents...");
      }
    }
    
    // AI analysis updates
    if (claim.aiDecision != null) {
      updates.add("✓ AI analysis complete");
      final confidence = claim.aiConfidenceScore ?? 0;
      if (confidence >= 0.8) {
        updates.add("✓ High confidence recommendation");
      } else {
        updates.add("⏳ Our team is reviewing for accuracy");
      }
    }
    
    // Human review updates
    if (claim.humanOverride != null) {
      updates.add("✓ Expert review complete");
      final reason = claim.humanOverride!['overrideReason'] as String?;
      if (reason != null && reason.isNotEmpty) {
        updates.add("✓ Additional notes added");
      }
    }
    
    // Final status
    if (claim.status == ClaimStatus.settled) {
      updates.add("✓ Payment processed");
    } else if (claim.status == ClaimStatus.denied) {
      updates.add("✓ Decision finalized");
    }
    
    return updates;
  }
  
  /// Generate encouraging message based on wait time
  static String _getDocumentReviewMessage(int documentCount, Duration elapsed) {
    if (elapsed.inMinutes < 2) {
      return "I'm analyzing your ${documentCount} document(s) right now. This usually takes just a few minutes!";
    } else if (elapsed.inMinutes < 5) {
      return "Still working on your documents. I'm being thorough to make sure everything is accurate.";
    } else if (elapsed.inMinutes < 10) {
      return "Almost there! I'm just double-checking all the details in your documents.";
    } else {
      return "Thanks for your patience! Your claim is getting the careful attention it deserves.";
    }
  }
  
  /// Get next action for the user
  static String? getNextAction(Claim claim) {
    if (claim.status == ClaimStatus.draft || claim.attachments.isEmpty) {
      return "Upload your vet records and receipts to continue";
    }
    
    if (claim.status == ClaimStatus.processing && claim.aiDecision == null) {
      return null; // No action needed, we're processing
    }
    
    if (claim.status == ClaimStatus.settled) {
      return "Check your email for payment details";
    }
    
    if (claim.status == ClaimStatus.denied) {
      return "Review the explanation and consider appealing if needed";
    }
    
    return null;
  }
}

/// Pawla message model
class PawlaMessage {
  final PawlaExpression expression;
  final String message;
  final MessageSentiment sentiment;
  
  PawlaMessage({
    required this.expression,
    required this.message,
    required this.sentiment,
  });
}

/// Message sentiment for analytics
enum MessageSentiment {
  positive,
  neutral,
  negative,
}

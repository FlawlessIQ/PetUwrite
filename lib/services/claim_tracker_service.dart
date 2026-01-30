import '../models/claim.dart';
import '../widgets/clover_avatar.dart';

/// Real-time claim tracker service
///
/// Generates contextual, empathetic status messages for Clover
/// based on claim status, processing stage, and time elapsed
class ClaimTrackerService {
  /// Get current status message for Clover
  static CloverMessage getCurrentMessage(Claim claim) {
    final status = claim.status;
    final hasDecision = claim.aiDecision != null;
    final elapsed = DateTime.now().difference(claim.updatedAt);

    if (status == ClaimStatus.settled) {
      return CloverMessage(
        expression: CloverExpression.celebrating,
        message:
            "🎉 Great news! Your claim has been approved and payment is on the way!",
        sentiment: MessageSentiment.positive,
      );
    }

    if (status == ClaimStatus.settling) {
      return CloverMessage(
        expression: CloverExpression.working,
        message:
            "✅ Your claim is approved. I'm initiating your reimbursement now — this typically takes 3-5 business days.",
        sentiment: MessageSentiment.positive,
      );
    }

    if (status == ClaimStatus.denied) {
      return CloverMessage(
        expression: CloverExpression.empathetic,
        message:
            "I know this isn't the news you hoped for. Let me explain why, and we can discuss next steps together.",
        sentiment: MessageSentiment.negative,
      );
    }

    if (status == ClaimStatus.awaitingInfo) {
      if (claim.attachments.isEmpty) {
        return CloverMessage(
          expression: CloverExpression.thinking,
          message:
              "To continue, please upload your vet records and receipts. Once they’re uploaded, we’ll pick up review automatically.",
          sentiment: MessageSentiment.neutral,
        );
      }

      return CloverMessage(
        expression: CloverExpression.thinking,
        message:
            "I’m ready to continue — I just need the requested details. Upload any missing documents (or reply in Clover) and I’ll keep going.",
        sentiment: MessageSentiment.neutral,
      );
    }

    if (status == ClaimStatus.processing) {
      // Different messages based on processing stage
      if (!hasDecision) {
        if (claim.attachments.isEmpty) {
          return CloverMessage(
            expression: CloverExpression.thinking,
            message:
                "I'm ready to review your claim! Just upload your vet records and receipts to get started.",
            sentiment: MessageSentiment.neutral,
          );
        } else {
          return CloverMessage(
            expression: CloverExpression.working,
            message: _getDocumentReviewMessage(
              claim.attachments.length,
              elapsed,
            ),
            sentiment: MessageSentiment.neutral,
          );
        }
      } else {
        // Automated checks complete; continue with next steps.
        final confidence = claim.aiConfidenceScore ?? 0.5;
        if (confidence >= 0.8) {
          return CloverMessage(
            expression: CloverExpression.happy,
            message:
                "Almost done! Your claim looks great. Just doing a final quality check...",
            sentiment: MessageSentiment.positive,
          );
        } else {
          return CloverMessage(
            expression: CloverExpression.thinking,
            message:
                "I couldn’t finalize this yet. I’ll request anything missing and continue automatically once it’s provided.",
            sentiment: MessageSentiment.neutral,
          );
        }
      }
    }

    if (status == ClaimStatus.draft) {
      return CloverMessage(
        expression: CloverExpression.happy,
        message:
            "Hi! I'm Clover, and I'm here to help you through the claims process. Let's get started!",
        sentiment: MessageSentiment.neutral,
      );
    }

    // Default fallback
    return CloverMessage(
      expression: CloverExpression.thinking,
      message: "I'm checking on your claim status. Hang tight!",
      sentiment: MessageSentiment.neutral,
    );
  }

  /// Get progress percentage (0-100)
  static int getProgressPercentage(Claim claim) {
    if (claim.status == ClaimStatus.settled ||
        claim.status == ClaimStatus.denied) {
      return 100;
    }

    if (claim.status == ClaimStatus.settling) {
      return 95;
    }

    int progress = 0;

    // Step 1: Filed (20%)
    progress += 20;

    // Step 2: Documents uploaded (20%)
    if (claim.attachments.isNotEmpty) {
      progress += 20;
    }

    // Step 3: Initial review complete (30%)
    if (claim.aiDecision != null) {
      progress += 30;
    }

    // Step 4: Waiting for info vs. final checks
    if (claim.status == ClaimStatus.awaitingInfo) {
      progress += 5;
    } else if (claim.aiConfidenceScore != null &&
        claim.aiConfidenceScore! >= 0.8) {
      progress += 15;
    }

    return progress.clamp(0, 95); // Never show 100% until truly complete
  }

  /// Get estimated time remaining
  static String getEstimatedTimeRemaining(Claim claim) {
    if (claim.status == ClaimStatus.settled ||
        claim.status == ClaimStatus.denied) {
      return "Complete";
    }

    if (claim.status == ClaimStatus.settling) {
      return "3-5 business days";
    }

    final hasDecision = claim.aiDecision != null;

    if (claim.status == ClaimStatus.awaitingInfo) {
      return claim.attachments.isEmpty
          ? "Waiting for documents"
          : "Waiting for details";
    }

    if (!hasDecision) {
      if (claim.attachments.isEmpty) {
        return "Waiting for documents";
      }
      return "5-10 minutes"; // automated review time
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

    // Review updates
    if (claim.aiDecision != null && claim.attachments.isNotEmpty) {
      updates.add("✓ Initial review complete");
      final confidence = claim.aiConfidenceScore ?? 0;
      if (confidence >= 0.8) {
        updates.add("✓ Final checks in progress");
      } else {
        updates.add("⏳ Verifying details");
      }
    }

    if (claim.status == ClaimStatus.awaitingInfo) {
      updates.add("⏳ Waiting for additional information");
    }

    // Final status
    if (claim.status == ClaimStatus.settled) {
      updates.add("✓ Payment processed");
    } else if (claim.status == ClaimStatus.settling) {
      updates.add("⏳ Payment processing");
    } else if (claim.status == ClaimStatus.denied) {
      updates.add("✓ Decision finalized");
    }

    return updates;
  }

  /// Generate encouraging message based on wait time
  static String _getDocumentReviewMessage(int documentCount, Duration elapsed) {
    if (elapsed.inMinutes < 2) {
      return "I'm analyzing your $documentCount document(s) right now. This usually takes just a few minutes!";
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

    if (claim.status == ClaimStatus.settling) {
      return "No action needed — payment is being processed";
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

/// Clover message model
class CloverMessage {
  final CloverExpression expression;
  final String message;
  final MessageSentiment sentiment;

  CloverMessage({
    required this.expression,
    required this.message,
    required this.sentiment,
  });
}

/// Message sentiment for analytics
enum MessageSentiment { positive, neutral, negative }

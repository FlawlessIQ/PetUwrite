# Claim Decision System - What You Need to Know

## Current Status

Your claims system is working! Claims are moving through the pipeline:
- ✅ **Draft** → User creating claim with Pawla
- ✅ **Submitted** → User uploaded documents and submitted
- ✅ **Processing** → AI is analyzing the claim

## What's Needed for a Final Decision

### The AI Decision Flow:

1. **Claim Submitted** with documents
2. **AI Analysis Triggered** (happening now!)
3. **AI Makes Decision**:
   - **Auto-Approve** (≥85% confidence + <$300)
   - **Auto-Deny** (clear policy exclusions)
   - **Escalate to Human** (uncertain or high-value claims)

### Current Situation

Looking at your console logs:
```
🤖 Starting claim decision process...
❌ Error processing claim decision: [cloud_firestore/permission-denied]
```

The AI tried to process but hit a permission issue when trying to update the claim with the decision result.

## The Issue

The AI decision engine is trying to write AI decision fields to the claim, but Firestore rules may be blocking certain field updates. Let me check what fields it's trying to write:

### AI Decision Fields:
- `aiConfidenceScore` - How confident the AI is (0-100%)
- `aiDecision` - approve/deny/escalate
- `aiReasoningExplanation` - Why the AI made that choice
- `status` - Updated to 'processing', 'settling', 'settled', or 'denied'

## Solution

The current rules allow users to update their claims in 'processing' status, but we need to ensure ALL fields can be updated, not just attachments.

### Option 1: Allow All Field Updates in Processing (Recommended)
Let the AI system (running in the user's context) update any field during processing.

### Option 2: Use Cloud Functions (More Secure)
Move AI processing to a Cloud Function that runs with admin privileges.

### Option 3: Manual Admin Review
Have an admin review and approve/deny the claim manually.

## For Right Now - Quick Test

Since the AI processing is having trouble completing, let's verify:

1. **Check if claims are in 'processing' status** ✅ (You showed one in processing!)
2. **The AI attempted to run** ✅ (Console logs show this)
3. **It failed on the update step** ❌ (Permission denied)

## What I'll Fix

I need to adjust the Firestore rules to allow the AI system to write the decision fields when updating a claim in 'processing' status.

Current rule:
```javascript
allow update: if resource.data.status == 'processing'
```

This allows the update, but Firestore might be checking specific field permissions. Let me add explicit field allowances.

## Expected Timeline for Decision

Once fixed:
1. **User submits claim with documents** → Instant
2. **AI analyzes** → 2-5 seconds
3. **AI makes decision** → Instant
4. **Claim status updated** → Instant

Total: **Under 10 seconds** for most claims!

For high-confidence, low-value claims:
- Auto-approved immediately
- Payout can be initiated

For uncertain or high-value claims:
- Escalated to human review
- Admin sees it in their dashboard
- Admin reviews and makes final call

## Test Scenario

Perfect test case (from your screenshot):
- **Claim:** Accident - broken leg
- **Amount:** $400
- **Status:** Processing
- **Has documents:** Yes (uploaded successfully)

This claim should:
1. ✅ Be analyzed by AI
2. ❓ Get confidence score
3. ❓ Either auto-approve (<$300 would auto-approve, but $400 might need human review)
4. ❓ Or escalate to admin dashboard

Let me fix the rules so step 2-4 can complete!

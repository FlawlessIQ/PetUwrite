/**
 * OpenAI API Proxy Cloud Functions
 * Securely handles OpenAI API calls server-side to protect API keys
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const axios = require("axios");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

function isEmulator() {
  // The Functions emulator sets different env vars depending on how it is started
  // (emulators:exec, emulators:start, unit tests, etc). Be generous here so we
  // never accidentally attempt to access Secret Manager or other production-only
  // resources while running locally.
  return (
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.FUNCTIONS_EMULATOR === "1" ||
    !!process.env.FIREBASE_EMULATOR_HUB ||
    !!process.env.FUNCTIONS_EMULATOR_HOST ||
    !!process.env.FIRESTORE_EMULATOR_HOST ||
    !!process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    !!process.env.FIREBASE_STORAGE_EMULATOR_HOST
  );
}

function isEmulatorOrNoOpenAISecret() {
  return isEmulator() || !openaiApiKey;
}

// Define the OpenAI API key as a secret (production only)
const openaiApiKey = isEmulator() ? null : defineSecret("OPENAI_API_KEY");

const OPENAI_CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions";
const FALLBACK_MODEL = "gpt-4o-mini";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const baseCallOptions = {
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
};

function callOptionsWithOpenAISecret(overrides = {}) {
  if (isEmulator() || !openaiApiKey) {
    return {
      ...baseCallOptions,
      ...overrides,
    };
  }

  return {
    ...baseCallOptions,
    ...overrides,
    secrets: [openaiApiKey],
  };
}

function isModelNotFoundError(error) {
  const status = error?.response?.status;
  const data = error?.response?.data;
  const code = data?.error?.code;
  const message = (data?.error?.message || "").toLowerCase();

  if (status === 404) return true;
  if (code === "model_not_found") return true;
  if (status === 400 && message.includes("model") && message.includes("not")) return true;
  if (message.includes("model") && (message.includes("not found") || message.includes("does not exist"))) {
    return true;
  }
  return false;
}

async function createChatCompletion({
  apiKey,
  model,
  messages,
  temperature,
  max_tokens,
  response_format,
  timeoutMs,
}) {
  const response = await axios.post(
      OPENAI_CHAT_COMPLETIONS_URL,
      {
        model,
        messages,
        temperature,
        max_tokens,
        ...(response_format ? {response_format} : {}),
      },
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: timeoutMs ?? 50000,
      },
  );

  return response.data;
}

/**
 * Conversational AI Chat Completion
 * Used for the quote flow conversation with Clover
 */
exports.chatCompletion = onCall(
    callOptionsWithOpenAISecret(),
    async (request) => {
      // Validate request
      if (!request.data || !request.data.messages) {
        throw new HttpsError(
            "invalid-argument",
            "Messages array is required",
        );
      }

      const {
        messages,
        model = "gpt-5.2",
        temperature = 0.7,
        response_format,
      } = request.data;

      // Allow callers to request larger outputs (e.g., structured JSON from long PDFs)
      // while enforcing a hard upper bound for cost/safety control.
      const requestedMaxTokens =
        request.data.max_tokens ?? request.data.maxTokens ?? 800;
      const maxTokens = Math.min(
          4096,
          Math.max(1, Number(requestedMaxTokens) || 800),
      );

      try {
        if (isEmulatorOrNoOpenAISecret()) {
          return {
            success: true,
            message: "(emulator) Clover is running locally.",
            usage: null,
            modelUsed: "emulator",
            emulated: true,
          };
        }

        let responseData;
        let modelUsed = model;

        try {
          responseData = await createChatCompletion({
            apiKey: openaiApiKey.value(),
            model,
            messages,
            temperature,
            max_tokens: maxTokens,
            response_format,
            timeoutMs: 50000,
          });
        } catch (error) {
          if (isModelNotFoundError(error) && model !== FALLBACK_MODEL) {
            console.warn(
                `Requested model '${model}' unavailable; falling back to '${FALLBACK_MODEL}'.`,
            );
            modelUsed = FALLBACK_MODEL;
            responseData = await createChatCompletion({
              apiKey: openaiApiKey.value(),
              model: FALLBACK_MODEL,
              messages,
              temperature,
              max_tokens: maxTokens,
              response_format,
              timeoutMs: 50000,
            });
          } else {
            throw error;
          }
        }

        return {
          success: true,
          message: responseData.choices[0].message.content,
          usage: responseData.usage,
          modelUsed,
        };
      } catch (error) {
        console.error("OpenAI API Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to get AI response",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Risk Analysis for Pet Insurance Quotes
 * Analyzes pet profile and returns risk assessment
 */
exports.analyzeRisk = onCall(
    callOptionsWithOpenAISecret(),
    async (request) => {
      const {petData, ownerData} = request.data;

      if (!petData) {
        throw new HttpsError("invalid-argument", "Pet data is required");
      }

      if (isEmulatorOrNoOpenAISecret()) {
        return {
          success: true,
          analysis: {
            riskScore: 42,
            riskFactors: ["emulator_mode"],
            recommendation: "review",
            reasoning: "Emulator mode: returning a deterministic stub response.",
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Analyze the following pet insurance quote for risk factors:

Pet Details:
- Name: ${petData.name}
- Species: ${petData.species}
- Breed: ${petData.breed}
- Age: ${petData.age} years
- Weight: ${petData.weight} lbs
- Pre-existing conditions: ${petData.preExistingConditions?.join(", ") || "None"}
- Spayed/Neutered: ${petData.isSpayedNeutered ? "Yes" : "No"}

Owner Details:
- Zip Code: ${ownerData?.zipCode || "Unknown"}

Provide a risk score (0-100) and brief analysis of key risk factors. Return ONLY a JSON object with this structure:
{
  "riskScore": <number 0-100>,
  "riskFactors": ["factor1", "factor2"],
  "recommendation": "approve" or "review" or "decline",
  "reasoning": "brief explanation"
}`;

      try {
        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: "gpt-5.2",
          messages: [
            {
              role: "system",
              content: "You are a pet insurance underwriting AI. Analyze risk factors and provide structured JSON responses only.",
            },
            {
              role: "user",
              content: prompt,
            },
          ],
          temperature: 0.3,
          max_tokens: 500,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const analysis = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: responseData.usage,
        };
      } catch (error) {
        console.error("Risk Analysis Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to analyze risk",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Claim Document Analysis
 * Analyzes veterinary documents for claim processing
 */
exports.analyzeClaimDocument = onCall(
    callOptionsWithOpenAISecret({
      maxInstances: 5,
      timeoutSeconds: 120,
      memory: "512MiB",
    }),
    async (request) => {
      const {documentText, claimType} = request.data;

      if (!documentText) {
        throw new HttpsError("invalid-argument", "Document text is required");
      }

      if (isEmulatorOrNoOpenAISecret()) {
        return {
          success: true,
          analysis: {
            claimType: claimType || "general",
            extractedAmount: null,
            notes: "Emulator mode: document analysis stub.",
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Analyze this veterinary document for a pet insurance claim:

Claim Type: ${claimType || "General"}

Document Text:
${documentText}

Extract and return ONLY a JSON object with:
{
  "diagnosis": "primary diagnosis",
  "treatmentDate": "YYYY-MM-DD or null",
  "veterinarianName": "name or null",
  "clinicName": "clinic name or null",
  "totalAmount": <number or null>,
  "proceduresPerformed": ["procedure1", "procedure2"],
  "confidence": <number 0-1>,
  "flags": ["any concerning items"],
  "isValid": <boolean>
}`;

      try {
        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: "gpt-5.2",
          messages: [
            {
              role: "system",
              content: "You are a veterinary document analysis AI. Extract structured information from vet records for insurance claims.",
            },
            {
              role: "user",
              content: prompt,
            },
          ],
          temperature: 0.1,
          max_tokens: 1000,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const analysis = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: responseData.usage,
        };
      } catch (error) {
        console.error("Document Analysis Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to analyze document",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Claim Decision Engine
 * Makes automated claim approval decisions
 */
exports.makeClaimDecision = onCall(
    callOptionsWithOpenAISecret({
      maxInstances: 5,
      timeoutSeconds: 60,
      memory: "256MiB",
    }),
    async (request) => {
      const {claimData, policyData, documentAnalysis} = request.data;

      if (!claimData || !policyData) {
        throw new HttpsError("invalid-argument", "Claim and policy data required");
      }

      if (isEmulatorOrNoOpenAISecret()) {
        return {
          success: true,
          decision: {
            decision: "review",
            approvedAmount: 0,
            confidence: 0.5,
            reasoning: "Emulator mode: returning deterministic decision stub.",
            denialReason: null,
            flagsForReview: ["emulator_mode"],
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Review this pet insurance claim and make a decision:

Claim Details:
- Type: ${claimData.claimType}
- Amount: $${claimData.claimAmount}
- Incident Date: ${claimData.incidentDate}
- Description: ${claimData.description}

Policy Details:
- Coverage Type: ${policyData.coverageType}
- Deductible: $${policyData.deductible}
- Coverage Limit: $${policyData.coverageLimit}
- Waiting Period Satisfied: ${policyData.waitingPeriodSatisfied}

Document Analysis:
${JSON.stringify(documentAnalysis, null, 2)}

Based on standard pet insurance underwriting guidelines, provide a decision. Return ONLY JSON:
{
  "decision": "approve" or "deny" or "review",
  "approvedAmount": <number or 0>,
  "confidence": <number 0-1>,
  "reasoning": "brief explanation",
  "denialReason": "reason if denied, or null",
  "flagsForReview": ["any items needing human review"]
}`;

      try {
        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: "gpt-5.2",
          messages: [
            {
              role: "system",
              content: "You are a pet insurance claims adjudication AI. Make fair, consistent claim decisions based on policy terms.",
            },
            {
              role: "user",
              content: prompt,
            },
          ],
          temperature: 0.2,
          max_tokens: 500,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const decision = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          decision,
          usage: responseData.usage,
        };
      } catch (error) {
        console.error("Claim Decision Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to make claim decision",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Process Claim Decision (Callable)
 *
 * Server-side claim decisioning to keep OpenAI keys off the client.
 * - Reads /claims/{claimId} and /policies/{policyId}
 * - Calls OpenAI to generate an approve/deny/review decision
 * - Writes aiDecision/aiConfidenceScore/aiReasoningExplanation back to the claim
 * - Keeps status in 'processing' on approval until payout is actually initiated
 */
exports.processClaimDecision = onCall(
    callOptionsWithOpenAISecret(),
    async (request) => {
      const claimId = request.data?.claimId;

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      if (!claimId || typeof claimId !== "string") {
        throw new HttpsError("invalid-argument", "claimId is required");
      }

      const uid = request.auth.uid;
      const isAdmin = request.auth.token?.admin === true;

      const claimRef = db.collection("claims").doc(claimId);
      const claimSnap = await claimRef.get();
      if (!claimSnap.exists) {
        throw new HttpsError("not-found", `Claim ${claimId} not found`);
      }

      const claim = claimSnap.data();
      if (!claim) {
        throw new HttpsError("internal", "Claim data missing");
      }

      if (!isAdmin && claim.ownerId !== uid) {
        throw new HttpsError("permission-denied", "Not authorized for this claim");
      }

      const policyId = claim.policyId;
      if (!policyId) {
        throw new HttpsError("failed-precondition", "Claim is missing policyId");
      }

      const policyRef = db.collection("policies").doc(policyId);
      const policySnap = await policyRef.get();
      if (!policySnap.exists) {
        throw new HttpsError("failed-precondition", `Policy ${policyId} not found`);
      }

      const policy = policySnap.data() || {};
      const plan = policy.plan || {};

      // Compute waiting period satisfaction (best-effort).
      const claimType = String(claim.claimType || "illness").toLowerCase();
      const waitingPeriodsDays = plan.waitingPeriodsDays || {};
      const waitingDays = Number(waitingPeriodsDays[claimType] ?? 0) || 0;
      const effectiveDate = policy.effectiveDate
          ? new Date(policy.effectiveDate)
          : null;
      const incidentDate = claim.incidentDate?.toDate
          ? claim.incidentDate.toDate()
          : (claim.incidentDate ? new Date(claim.incidentDate) : null);

      let waitingPeriodSatisfied = true;
      if (effectiveDate && incidentDate) {
        const msDiff = incidentDate.getTime() - effectiveDate.getTime();
        const daysDiff = msDiff / (1000 * 60 * 60 * 24);
        waitingPeriodSatisfied = daysDiff >= waitingDays;
      }

      const coverageLimit = plan.isUnlimitedAnnualCoverage === true
          ? "Unlimited"
          : (plan.maxAnnualCoverage ?? null);

      const decisionPrompt = `Review this pet insurance claim and make a decision.

Claim Details:
- Type: ${claimType}
- Amount: $${Number(claim.claimAmount || 0).toFixed(2)}
- Incident Date: ${claim.incidentDate?.toDate ? claim.incidentDate.toDate().toISOString() : (claim.incidentDate || "")}
- Description: ${claim.description || ""}
- Attachments: ${Array.isArray(claim.attachments) ? claim.attachments.length : 0}

Policy Details:
- Plan: ${plan.name || plan.type || ""}
- Deductible: $${Number(plan.annualDeductible || 0).toFixed(2)}
- Reimbursement: ${plan.reimbursementPercent ?? (100 - (plan.coPayPercentage ?? 20))}%
- Coverage Limit: ${coverageLimit}
- Waiting Period Satisfied: ${waitingPeriodSatisfied}

Return ONLY JSON:
{
  "decision": "approve" or "deny" or "review",
  "confidence": <number 0-1>,
  "reasoning": "brief explanation",
  "denialReason": "reason if denied, or null",
  "flagsForReview": ["any items needing human review"]
}`;

      // Emulator-safe path: avoid external calls and secrets.
      if (isEmulatorOrNoOpenAISecret()) {
        const emuDecision = {
          decision: "approve",
          confidence: 0.82,
          reasoning: "Emulator mode: auto-approving for end-to-end smoke test.",
          denialReason: null,
          flagsForReview: [],
        };

        const normalizedDecision = "approve";
        const confidence = emuDecision.confidence;
        const aiDecision = "approve";
        const newStatus = "processing";
        const modelUsed = "emulator";

        const aiReasoningExplanation = {
          explanation: emuDecision.reasoning,
          confidenceScore: confidence,
          denialReason: null,
          flagsForReview: [],
          modelUsed,
          processedAt: new Date().toISOString(),
          waitingPeriodSatisfied,
          waitingDays,
        };

        await claimRef.update({
          status: newStatus,
          aiDecision,
          aiConfidenceScore: confidence,
          aiReasoningExplanation,
          updatedAt: FieldValue.serverTimestamp(),
        });

        await claimRef.collection("ai_audit_trail").add({
          claimId,
          timestamp: FieldValue.serverTimestamp(),
          eventType: "ai_decision",
          performedBy: "system",
          performedFor: uid,
          decision: {
            decision: normalizedDecision,
            confidence,
            reasoning: emuDecision.reasoning,
            denialReason: null,
            flagsForReview: [],
          },
          metadata: {
            modelUsed,
          },
        });

        return {
          success: true,
          claimId,
          decision: {
            decision: normalizedDecision,
            confidence,
            reasoning: emuDecision.reasoning,
            denialReason: null,
            flagsForReview: [],
          },
          status: newStatus,
          modelUsed,
          emulated: true,
        };
      }

      let responseData;
      let modelUsed = "gpt-5.2";

      try {
        responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: modelUsed,
          messages: [
            {
              role: "system",
              content: "You are a pet insurance claims adjudication AI. Make fair, consistent claim decisions based on policy terms.",
            },
            {role: "user", content: decisionPrompt},
          ],
          temperature: 0.2,
          max_tokens: 500,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });
      } catch (error) {
        if (isModelNotFoundError(error)) {
          modelUsed = FALLBACK_MODEL;
          responseData = await createChatCompletion({
            apiKey: openaiApiKey.value(),
            model: modelUsed,
            messages: [
              {
                role: "system",
                content: "You are a pet insurance claims adjudication AI. Make fair, consistent claim decisions based on policy terms.",
              },
              {role: "user", content: decisionPrompt},
            ],
            temperature: 0.2,
            max_tokens: 500,
            response_format: {type: "json_object"},
            timeoutMs: 50000,
          });
        } else {
          console.error("Claim Decision Error:", error.response?.data || error.message);
          throw new HttpsError(
              "internal",
              "Failed to make claim decision",
              error.response?.data || error.message,
          );
        }
      }

      let decision;
      try {
        decision = JSON.parse(responseData.choices[0].message.content);
      } catch (e) {
        throw new HttpsError("internal", `Invalid JSON from model: ${e?.message || e}`);
      }

      const normalizedDecision = String(decision.decision || "review").toLowerCase();
      const confidence = Math.max(0, Math.min(1, Number(decision.confidence) || 0));

      // Map decision -> claim fields.
      const aiDecision = normalizedDecision === "approve"
          ? "approve"
          : normalizedDecision === "deny"
            ? "deny"
            : "escalate";

      // IMPORTANT: do not mark as 'settling' here until payout initiation is implemented.
      const newStatus = normalizedDecision === "deny" ? "denied" : "processing";

      const aiReasoningExplanation = {
        explanation: decision.reasoning || "",
        confidenceScore: confidence,
        denialReason: decision.denialReason || null,
        flagsForReview: Array.isArray(decision.flagsForReview) ? decision.flagsForReview : [],
        modelUsed,
        processedAt: new Date().toISOString(),
        waitingPeriodSatisfied,
        waitingDays,
      };

      await claimRef.update({
        status: newStatus,
        aiDecision,
        aiConfidenceScore: confidence,
        aiReasoningExplanation,
        updatedAt: FieldValue.serverTimestamp(),
        ...(newStatus === "denied" ? {deniedAt: FieldValue.serverTimestamp()} : {}),
      });

      await claimRef.collection("ai_audit_trail").add({
        claimId,
        timestamp: FieldValue.serverTimestamp(),
        eventType: "ai_decision",
        performedBy: "system",
        performedFor: uid,
        decision: {
          decision: normalizedDecision,
          confidence,
          reasoning: decision.reasoning || "",
          denialReason: decision.denialReason || null,
          flagsForReview: Array.isArray(decision.flagsForReview) ? decision.flagsForReview : [],
        },
        metadata: {
          modelUsed,
        },
      });

      return {
        success: true,
        claimId,
        decision: {
          decision: normalizedDecision,
          confidence,
          reasoning: decision.reasoning || "",
          denialReason: decision.denialReason || null,
          flagsForReview: Array.isArray(decision.flagsForReview) ? decision.flagsForReview : [],
        },
        status: newStatus,
        modelUsed,
      };
    },
);

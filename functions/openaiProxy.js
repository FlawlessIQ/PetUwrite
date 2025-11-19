/**
 * OpenAI API Proxy Cloud Functions
 * Securely handles OpenAI API calls server-side to protect API keys
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const axios = require("axios");
const {defineSecret} = require("firebase-functions/params");

// Define the OpenAI API key as a secret
const openaiApiKey = defineSecret("OPENAI_API_KEY");

/**
 * Conversational AI Chat Completion
 * Used for the quote flow conversation with Clover
 */
exports.chatCompletion = onCall(
    {
      secrets: [openaiApiKey],
      maxInstances: 10,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      // Validate request
      if (!request.data || !request.data.messages) {
        throw new HttpsError(
            "invalid-argument",
            "Messages array is required",
        );
      }

      const {messages, model = "gpt-4o-mini", temperature = 0.7} = request.data;

      try {
        const response = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            {
              model,
              messages,
              temperature,
              max_tokens: 500,
            },
            {
              headers: {
                "Authorization": `Bearer ${openaiApiKey.value()}`,
                "Content-Type": "application/json",
              },
              timeout: 50000, // 50 second timeout
            },
        );

        return {
          success: true,
          message: response.data.choices[0].message.content,
          usage: response.data.usage,
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
    {
      secrets: [openaiApiKey],
      maxInstances: 10,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      const {petData, ownerData} = request.data;

      if (!petData) {
        throw new HttpsError("invalid-argument", "Pet data is required");
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
        const response = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            {
              model: "gpt-4o-mini",
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
            },
            {
              headers: {
                "Authorization": `Bearer ${openaiApiKey.value()}`,
                "Content-Type": "application/json",
              },
            },
        );

        const analysis = JSON.parse(response.data.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: response.data.usage,
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
    {
      secrets: [openaiApiKey],
      maxInstances: 5,
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      const {documentText, claimType} = request.data;

      if (!documentText) {
        throw new HttpsError("invalid-argument", "Document text is required");
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
        const response = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            {
              model: "gpt-4o-mini",
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
            },
            {
              headers: {
                "Authorization": `Bearer ${openaiApiKey.value()}`,
                "Content-Type": "application/json",
              },
            },
        );

        const analysis = JSON.parse(response.data.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: response.data.usage,
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
    {
      secrets: [openaiApiKey],
      maxInstances: 5,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      const {claimData, policyData, documentAnalysis} = request.data;

      if (!claimData || !policyData) {
        throw new HttpsError("invalid-argument", "Claim and policy data required");
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
        const response = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            {
              model: "gpt-4o-mini",
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
            },
            {
              headers: {
                "Authorization": `Bearer ${openaiApiKey.value()}`,
                "Content-Type": "application/json",
              },
            },
        );

        const decision = JSON.parse(response.data.choices[0].message.content);

        return {
          success: true,
          decision,
          usage: response.data.usage,
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

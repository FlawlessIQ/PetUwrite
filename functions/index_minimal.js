/**
 * Minimal Cloud Functions export - OpenAI Proxy only
 * Temporary file to deploy OpenAI proxy functions without loading problematic modules
 */

const openaiProxy = require("./openaiProxy");

// Export OpenAI proxy functions
exports.chatCompletion = openaiProxy.chatCompletion;
exports.analyzeRisk = openaiProxy.analyzeRisk;
exports.analyzeClaimDocument = openaiProxy.analyzeClaimDocument;
exports.makeClaimDecision = openaiProxy.makeClaimDecision;

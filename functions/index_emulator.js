/**
 * Minimal Cloud Functions export for emulators.
 *
 * Purpose:
 * - Keep emulator startup stable and fast.
 * - Avoid loading legacy modules that rely on deprecated runtime config.
 */

const openaiProxy = require("./openaiProxy");
const claimsReconciliation = require("./claimsReconciliation");
const reimbursements = require("./reimbursements");

const {onCall} = require("firebase-functions/v2/https");

// Basic health check for emulator debugging.
exports.ping = onCall(async () => ({ok: true, emulated: true}));

// Claims pipeline (E2E)
exports.processClaimDecision = openaiProxy.processClaimDecision;
exports.getClaimAttachmentExtractionHealth = openaiProxy.getClaimAttachmentExtractionHealth;
exports.onClaimUpdatedAutoDecision = openaiProxy.onClaimUpdatedAutoDecision;
exports.onClaimAttachmentCreated = openaiProxy.onClaimAttachmentCreated;
exports.onClaimAttachmentUpdated = openaiProxy.onClaimAttachmentUpdated;
exports.retryClaimAttachmentExtractions = openaiProxy.retryClaimAttachmentExtractions;
exports.processClaimPayout = claimsReconciliation.processClaimPayout;

// Customer reimbursement method (Stripe Connect onboarding)
exports.createReimbursementOnboardingLink =
	reimbursements.createReimbursementOnboardingLink;
exports.refreshReimbursementSetupStatus =
	reimbursements.refreshReimbursementSetupStatus;

// Useful helpers for local ops/debug (safe, no external dependencies)
exports.retryFailedOperation = claimsReconciliation.retryFailedOperation;

// Keep these available for smoke-testing public unauth flows if needed
const underwritingRulesPublic = require("./underwritingRulesPublic");
exports.getUnderwritingRulesPublic = underwritingRulesPublic.getUnderwritingRulesPublic;

const productCatalogPublic = require("./productCatalogPublic");
exports.getProductCatalogPublic = productCatalogPublic.getProductCatalogPublic;

// Draft save/resume (anonymous auth + resume key)
const drafts = require("./drafts");
exports.upsertDraft = drafts.upsertDraft;
exports.resolveDraft = drafts.resolveDraft;
exports.clearDraft = drafts.clearDraft;

// Vet record parsing helpers (PDF + image OCR)
// These are safe to expose in emulators for local testing.
const pdfExtraction = require("./pdfExtraction");
exports.extractPdfText = pdfExtraction.extractPdfText;

const imageExtraction = require("./imageExtraction");
exports.extractImageText = imageExtraction.extractImageText;

// Policy binding (admin write)
const policies = require("./policies");
exports.createPolicy = policies.createPolicy;

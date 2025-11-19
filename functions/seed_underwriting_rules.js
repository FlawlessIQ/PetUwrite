#!/usr/bin/env node
/**
 * Firebase Admin SDK CLI Tool to Seed Underwriting Rules
 *
 * This script creates the admin_settings/underwriting_rules document in Firestore
 * with the complete underwriting rules schema.
 *
 * Usage:
 *   node seed_underwriting_rules.js
 *
 * Prerequisites:
 *   1. npm install firebase-admin
 *   2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable
 *      OR place service account key as firebase-service-account.json
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// Initialize Firebase Admin SDK
function initializeFirebase() {
  console.log("🔧 Initializing Firebase Admin SDK...\n");

  try {
    // Method 1: Try service account file in current directory
    const serviceAccountPath = path.join(__dirname, "firebase-service-account.json");

    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log("✅ Firebase initialized with service account file (functions/)\n");
      return;
    }

    // Method 2: Try service account in parent directory
    const parentServiceAccountPath = path.join(__dirname, "..", "firebase-service-account.json");
    if (fs.existsSync(parentServiceAccountPath)) {
      const serviceAccount = require(parentServiceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log("✅ Firebase initialized with service account file (root/)\n");
      return;
    }

    // Method 3: Try GOOGLE_APPLICATION_CREDENTIALS environment variable
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      console.log("✅ Firebase initialized with GOOGLE_APPLICATION_CREDENTIALS\n");
      return;
    }

    // Method 4: Try default credentials (works in Cloud Shell, GCE, Cloud Functions)
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      console.log("✅ Firebase initialized with default credentials\n");
      return;
    } catch (defaultError) {
      // Continue to error message
    }

    // No credentials found
    console.error("❌ No Firebase credentials found.\n");
    console.error("📝 Please choose ONE of these options:\n");
    console.error("   Option 1: Download Service Account Key");
    console.error("   ─────────────────────────────────────────");
    console.error("   1. Go to Firebase Console → Project Settings → Service Accounts");
    console.error("   2. Click \"Generate New Private Key\"");
    console.error("   3. Save as firebase-service-account.json in functions/ directory");
    console.error("   4. Re-run: node seed_underwriting_rules.js\n");
    console.error("   Option 2: Set Environment Variable");
    console.error("   ────────────────────────────────────────");
    console.error("   export GOOGLE_APPLICATION_CREDENTIALS=\"/path/to/service-account.json\"");
    console.error("   node seed_underwriting_rules.js\n");
    process.exit(1);
  } catch (error) {
    console.error("❌ Firebase initialization error:", error.message);
    process.exit(1);
  }
}

// Seed underwriting rules to Firestore
async function seedUnderwritingRules() {
  console.log("📋 Preparing underwriting rules document...\n");

  const underwritingRules = {
    enabled: true,
    maxRiskScore: 85,
    minAgeMonths: 8,
    maxAgeYears: 12,
    excludedBreeds: [
      "Wolf Hybrid",
      "Pit Bull Terrier",
      "American Bulldog",
      "Presa Canario",
      "Cane Corso",
      "Dogo Argentino",
    ],
    criticalConditions: [
      "cancer",
      "heart murmur",
      "epilepsy",
      "terminal illness",
      "seizure disorder",
      "chronic kidney disease",
    ],
    excludableConditions: [
      "allergies",
      "arthritis",
      "hip dysplasia",
      "skin conditions",
      "ear infections",
      "diabetes",
      "asthma",
      "dental disease",
      "obesity",
      "anxiety",
    ],
    rejectionRules: [
      {
        ruleId: "AGE_TOO_YOUNG",
        description: "Pet is too young for coverage",
        condition: "pet.ageMonths < minAgeMonths",
        autoDecline: true,
      },
      {
        ruleId: "AGE_TOO_OLD",
        description: "Pet exceeds maximum age for new policies",
        condition: "pet.ageMonths > maxAgeYears * 12",
        autoDecline: true,
      },
      {
        ruleId: "BREED_EXCLUDED",
        description: "Breed is excluded from underwriting",
        condition: "pet.breed in excludedBreeds",
        autoDecline: true,
      },
      {
        ruleId: "HIGH_RISK_SCORE",
        description: "AI Risk Score exceeds allowable maximum",
        condition: "riskScore.total > maxRiskScore",
        autoDecline: true,
      },
      {
        ruleId: "CRITICAL_CONDITION",
        description: "Pre-existing condition is uninsurable",
        condition: "pet.conditions containsAny criticalConditions",
        autoDecline: true,
      },
    ],
    aiPromptOverrides: {
      riskDeclineTriggers: [
        "riskScore > 85",
        "condition in [cancer, epilepsy, terminal illness]",
        "breed in [Wolf Hybrid, Pit Bull Terrier]",
        "pet.ageMonths < 8 or pet.ageYears > 12",
      ],
      recommendationLogic:
        "If any of the above are true, recommend: eligibility = 'deny'",
    },
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: "system_seed",
  };

  try {
    const db = admin.firestore();

    console.log("💾 Writing to Firestore: admin_settings/underwriting_rules...");
    await db
        .collection("admin_settings")
        .doc("underwriting_rules")
        .set(underwritingRules);

    console.log("\n✅ Underwriting rules successfully seeded to Firestore.\n");
    console.log("📊 Summary:");
    console.log(`   Collection: admin_settings`);
    console.log(`   Document: underwriting_rules`);
    console.log(`   Max Risk Score: ${underwritingRules.maxRiskScore}`);
    console.log(`   Age Range: ${underwritingRules.minAgeMonths} months - ${underwritingRules.maxAgeYears} years`);
    console.log(`   Excluded Breeds: ${underwritingRules.excludedBreeds.length}`);
    console.log(`   Critical Conditions: ${underwritingRules.criticalConditions.length}`);
    console.log(`   Rejection Rules: ${underwritingRules.rejectionRules.length}`);

    console.log("\n🎯 Next Steps:");
    console.log("   1. Verify in Firebase Console: Firestore → admin_settings → underwriting_rules");
    console.log("   2. Run your Flutter app - permission errors should be resolved");
    console.log("   3. Test underwriting flow with excluded breeds and critical conditions");
    console.log("   4. Check Admin Dashboard for risk-based quote filtering\n");

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Error seeding underwriting rules:", error.message);
    console.error("\n🔍 Troubleshooting:");
    console.error("   1. Verify Firebase project ID is correct");
    console.error("   2. Check service account has Firestore write permissions");
    console.error("   3. Ensure firestore.rules allow writes to admin_settings collection");
    console.error("   4. Verify network connectivity to Firebase");
    console.error("\n📝 Error Details:", error);
    process.exit(1);
  }
}

// Main execution
async function main() {
  console.log("═══════════════════════════════════════════════════════════");
  console.log("  PetUwrite - Underwriting Rules Seeder");
  console.log("═══════════════════════════════════════════════════════════\n");

  initializeFirebase();
  await seedUnderwritingRules();
}

// Run the script
main();

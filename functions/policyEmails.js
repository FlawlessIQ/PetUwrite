const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");
const PDFDocument = require("pdfkit");
const {Storage} = require("@google-cloud/storage");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = new Storage();
const POLICY_EMAIL_LOG_PREFIX = "policy_activation_";

function getStorageBucketName() {
  const explicit = process.env.STORAGE_BUCKET;
  if (explicit) return explicit;

  const fromAdmin = admin.app()?.options?.storageBucket;
  if (fromAdmin) return fromAdmin;

  try {
    const raw = process.env.FIREBASE_CONFIG;
    if (!raw) return undefined;
    const parsed = JSON.parse(raw);
    return parsed?.storageBucket;
  } catch (_) {
    return undefined;
  }
}

function getSendGridApiKey() {
  if (process.env.SENDGRID_API_KEY) {
    return process.env.SENDGRID_API_KEY;
  }

  try {
    const functions = require("firebase-functions");
    return functions.config()?.sendgrid?.key || null;
  } catch (_) {
    return null;
  }
}

function createTransporter() {
  const apiKey = getSendGridApiKey();
  if (!apiKey) {
    return null;
  }

  return nodemailer.createTransport({
    host: "smtp.sendgrid.net",
    port: 587,
    auth: {
      user: "apikey",
      pass: apiKey,
    },
  });
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value?.toDate === "function") return value.toDate();

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatDate(value) {
  const date = toDate(value);
  return date ? date.toLocaleDateString("en-US") : "TBD";
}

function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
      .map((item) => (item == null ? "" : String(item).trim()))
      .filter(Boolean);
}

function fullName(owner) {
  const first = (owner?.firstName || "").toString().trim();
  const last = (owner?.lastName || "").toString().trim();
  return [first, last].filter(Boolean).join(" ").trim();
}

function normalizePolicyData(policyData) {
  const owner = policyData?.owner && typeof policyData.owner === "object" ?
    policyData.owner :
    {};
  const pet = policyData?.pet && typeof policyData.pet === "object" ?
    policyData.pet :
    {};
  const plan = policyData?.plan && typeof policyData.plan === "object" ?
    policyData.plan :
    {};

  return {
    ...policyData,
    policyNumber: policyData?.policyNumber || "Pending",
    owner: {
      firstName: owner.firstName || "",
      lastName: owner.lastName || "",
      email: owner.email || "",
      phone: owner.phone || owner.phoneNumber || "",
      addressLine1: owner.addressLine1 || owner.address?.street || "",
      addressLine2: owner.addressLine2 || "",
      city: owner.city || owner.address?.city || "",
      state: owner.state || owner.address?.state || "",
      zipCode: owner.zipCode || owner.address?.zipCode || owner.address?.zip || "",
    },
    pet: {
      name: pet.name || "Pet",
      species: pet.species || "Unknown",
      breed: pet.breed || "Unknown",
      age: asNumber(pet.age, 0),
      gender: pet.gender || "Unknown",
      weight: asNumber(pet.weight, 0),
    },
    plan: {
      name: plan.name || plan.type || "Clovara Policy",
      monthlyPremium: asNumber(plan.monthlyPremium, 0),
      annualDeductible: asNumber(plan.annualDeductible, 0),
      coPayPercentage: asNumber(plan.coPayPercentage, 20),
      maxAnnualCoverage: plan.maxAnnualCoverage == null ?
        null :
        asNumber(plan.maxAnnualCoverage, 0),
      features: asStringArray(plan.features),
      exclusions: asStringArray(plan.exclusions),
    },
    effectiveDate: toDate(policyData?.effectiveDate),
    expirationDate: toDate(policyData?.expirationDate),
  };
}

function getPolicyEmailLogId(policyId) {
  return `${POLICY_EMAIL_LOG_PREFIX}${policyId}`;
}

async function generatePolicyPDFBuffer(policyData) {
  return new Promise((resolve, reject) => {
    try {
      const normalized = normalizePolicyData(policyData);
      const doc = new PDFDocument({size: "LETTER", margin: 50});
      const buffers = [];

      doc.on("data", buffers.push.bind(buffers));
      doc.on("end", () => resolve(Buffer.concat(buffers)));

      doc
          .fontSize(24)
          .fillColor("#1E40AF")
          .text("Pet Insurance Policy", {align: "center"})
          .moveDown();

      doc
          .fontSize(12)
          .fillColor("#000000")
          .text(`Policy Number: ${normalized.policyNumber}`, {align: "center"})
          .moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Policy Holder Information")
          .moveDown(0.5);

      doc
          .fontSize(12)
          .fillColor("#000000")
          .text(`Name: ${fullName(normalized.owner) || "Unknown"}`)
          .text(`Email: ${normalized.owner.email || "Unavailable"}`)
          .text(`Phone: ${normalized.owner.phone || "Unavailable"}`)
          .text(
              `Address: ${normalized.owner.addressLine1 || "Unavailable"}${
                normalized.owner.addressLine2 ?
                  `, ${normalized.owner.addressLine2}` :
                  ""
              }`,
          )
          .text(
              `         ${normalized.owner.city || ""}, ${normalized.owner.state || ""} ${normalized.owner.zipCode || ""}`.trim(),
          )
          .moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Insured Pet Information")
          .moveDown(0.5);

      doc
          .fontSize(12)
          .fillColor("#000000")
          .text(`Name: ${normalized.pet.name}`)
          .text(`Species: ${normalized.pet.species}`)
          .text(`Breed: ${normalized.pet.breed}`)
          .text(`Age: ${normalized.pet.age} years`)
          .text(`Gender: ${normalized.pet.gender}`)
          .text(`Weight: ${normalized.pet.weight} lbs`)
          .moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Coverage Details")
          .moveDown(0.5);

      const annualMaximum = normalized.plan.maxAnnualCoverage == null ?
        "Unlimited" :
        `$${normalized.plan.maxAnnualCoverage.toLocaleString("en-US")}`;
      doc
          .fontSize(12)
          .fillColor("#000000")
          .text(`Plan: ${normalized.plan.name}`)
          .text(`Monthly Premium: $${normalized.plan.monthlyPremium.toFixed(2)}`)
          .text(`Annual Premium: $${(normalized.plan.monthlyPremium * 12).toFixed(2)}`)
          .text(`Annual Deductible: $${normalized.plan.annualDeductible.toFixed(0)}`)
          .text(`Reimbursement: ${100 - normalized.plan.coPayPercentage}%`)
          .text(`Annual Maximum: ${annualMaximum}`)
          .moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Coverage Period")
          .moveDown(0.5);

      doc
          .fontSize(12)
          .fillColor("#000000")
          .text(`Effective Date: ${formatDate(normalized.effectiveDate)}`)
          .text(`Expiration Date: ${formatDate(normalized.expirationDate)}`)
          .moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Covered Benefits")
          .moveDown(0.5);

      doc.fontSize(12).fillColor("#000000");
      const features = normalized.plan.features.length ?
        normalized.plan.features :
        ["Refer to your Clovara coverage summary for included benefits."];
      features.forEach((feature) => doc.text(`- ${feature}`));
      doc.moveDown(2);

      doc
          .fontSize(16)
          .fillColor("#1E40AF")
          .text("Policy Exclusions")
          .moveDown(0.5);

      doc.fontSize(12).fillColor("#000000");
      const exclusions = normalized.plan.exclusions.length ?
        normalized.plan.exclusions :
        ["See the full policy terms for applicable exclusions and waiting periods."];
      exclusions.forEach((exclusion) => doc.text(`- ${exclusion}`));
      doc.moveDown(2);

      doc
          .fontSize(10)
          .fillColor("#666666")
          .text(
              "This policy is subject to the terms and conditions outlined in your full policy documents.",
              {align: "center"},
          )
          .text("For questions or claims, contact support@clovara.com", {
            align: "center",
          })
          .moveDown();

      doc
          .fontSize(8)
          .text(`Document generated on ${formatDate(new Date())}`, {
            align: "center",
          });

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

function getPolicyEmailTemplate(recipientName, policyData) {
  const normalized = normalizePolicyData(policyData);
  const displayName = recipientName || fullName(normalized.owner) || "Valued Customer";
  const dashboardUrl = "https://pet-underwriter-ai.web.app/dashboard";

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #1E40AF;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9fafb;
          padding: 30px;
          border-radius: 0 0 8px 8px;
        }
        .policy-box {
          background-color: white;
          padding: 20px;
          margin: 20px 0;
          border-radius: 8px;
          border-left: 4px solid #1E40AF;
        }
        .button {
          display: inline-block;
          background-color: #1E40AF;
          color: white;
          padding: 12px 24px;
          text-decoration: none;
          border-radius: 6px;
          margin: 20px 0;
        }
        .footer {
          text-align: center;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #ddd;
          color: #666;
          font-size: 14px;
        }
        .highlight {
          color: #1E40AF;
          font-weight: bold;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Your Policy is Active!</h1>
        <p>Welcome to Clovara</p>
      </div>

      <div class="content">
        <p>Dear ${displayName},</p>

        <p>Your pet insurance policy is now <strong>active</strong> and your pet is protected.</p>

        <div class="policy-box">
          <h2>Policy Details</h2>
          <p><strong>Policy Number:</strong> <span class="highlight">${normalized.policyNumber}</span></p>
          <p><strong>Pet Name:</strong> ${normalized.pet.name}</p>
          <p><strong>Plan:</strong> ${normalized.plan.name}</p>
          <p><strong>Monthly Premium:</strong> $${normalized.plan.monthlyPremium.toFixed(2)}</p>
          <p><strong>Coverage Start:</strong> ${formatDate(normalized.effectiveDate)}</p>
        </div>

        <h3>What&apos;s Next?</h3>
        <ol>
          <li><strong>Review Your Policy:</strong> Your policy document is attached to this email.</li>
          <li><strong>Save Your Documents:</strong> Keep this email and the attached PDF for your records.</li>
          <li><strong>Use Your Dashboard:</strong> Review coverage and file claims online when you need to.</li>
        </ol>

        <div style="text-align: center;">
          <a href="${dashboardUrl}" class="button">Go to Dashboard</a>
        </div>

        <div class="policy-box">
          <h3>Need Help?</h3>
          <p>Our support team is here for you:</p>
          <ul>
            <li>Email: support@clovara.com</li>
          </ul>
        </div>

        <p>Thank you for choosing Clovara.</p>

        <p>Best regards,<br>
        <strong>The Clovara Team</strong></p>
      </div>

      <div class="footer">
        <p>Clovara</p>
        <p>This email was sent to ${normalized.owner.email || "your email address"}</p>
      </div>
    </body>
    </html>
  `;
}

async function generatePolicyPDFForPolicy({
  policyId,
  policyNumber,
  policyData,
  force = false,
}) {
  if (!policyId) {
    throw new HttpsError("invalid-argument", "policyId is required");
  }

  const bucketName = getStorageBucketName();
  if (!bucketName) {
    throw new HttpsError(
        "failed-precondition",
        "Missing storage bucket configuration (set STORAGE_BUCKET or storageBucket in FIREBASE_CONFIG)",
    );
  }

  const policyRef = db.collection("policies").doc(policyId);
  if (!force) {
    const existingSnap = await policyRef.get();
    const existingData = existingSnap.exists ? existingSnap.data() : null;
    const existingPath = existingData?.pdfStoragePath;

    if (existingPath) {
      const existingFile = storage.bucket(bucketName).file(existingPath);
      const [exists] = await existingFile.exists();
      if (exists) {
        const [pdfUrl] = await existingFile.getSignedUrl({
          action: "read",
          expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
        });

        await policyRef.set({
          pdfUrl,
          pdfLastSignedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        return {success: true, pdfUrl, reused: true, storagePath: existingPath};
      }
    }
  }

  const normalized = normalizePolicyData(policyData);
  const pdfBuffer = await generatePolicyPDFBuffer(normalized);
  const safePolicyNumber = (policyNumber || normalized.policyNumber || policyId)
      .toString()
      .replace(/[^\w.-]+/g, "_");
  const storagePath = `policies/${policyId}/${safePolicyNumber}.pdf`;
  const file = storage.bucket(bucketName).file(storagePath);

  await file.save(pdfBuffer, {
    metadata: {
      contentType: "application/pdf",
      metadata: {
        policyId,
        policyNumber: normalized.policyNumber,
        createdAt: new Date().toISOString(),
      },
    },
  });

  const [pdfUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
  });

  await policyRef.set({
    pdfUrl,
    pdfStoragePath: storagePath,
    pdfGeneratedAt: FieldValue.serverTimestamp(),
    pdfLastSignedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {success: true, pdfUrl, reused: false, storagePath};
}

async function sendPolicyEmailForPolicy({
  policyId,
  policyNumber,
  recipientEmail,
  recipientName,
  policyData,
  force = false,
}) {
  if (!policyId) {
    throw new HttpsError("invalid-argument", "policyId is required");
  }

  const normalized = normalizePolicyData(policyData);
  const resolvedRecipient = (recipientEmail || normalized.owner.email || "")
      .toString()
      .trim();
  if (!resolvedRecipient) {
    logger.warn("Skipping policy email with no recipient", {policyId});
    return {success: false, skipped: true, reason: "missing-recipient"};
  }

  const transporter = createTransporter();
  if (!transporter) {
    logger.warn("SENDGRID_API_KEY not configured, skipping policy email", {
      policyId,
      recipientEmail: resolvedRecipient,
    });
    return {
      success: false,
      skipped: true,
      reason: "missing-sendgrid-config",
    };
  }

  const logRef = db.collection("email_logs").doc(getPolicyEmailLogId(policyId));
  if (!force) {
    const shouldSend = await db.runTransaction(async (transaction) => {
      const existingLog = await transaction.get(logRef);
      const existingStatus = existingLog.exists ? existingLog.data()?.status : null;
      if (existingStatus === "sent" || existingStatus === "processing") {
        return false;
      }

      transaction.set(logRef, {
        policyId,
        recipientEmail: resolvedRecipient,
        status: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });

    if (!shouldSend) {
      return {success: true, skipped: true, reason: "already-sent"};
    }
  }

  const pdfBuffer = await generatePolicyPDFBuffer(normalized);
  const subject = `Your Clovara Pet Insurance Policy - ${policyNumber || normalized.policyNumber}`;

  try {
    await transporter.sendMail({
      from: "Clovara <noreply@clovara.com>",
      to: resolvedRecipient,
      subject,
      html: getPolicyEmailTemplate(
          recipientName || fullName(normalized.owner),
          normalized,
      ),
      attachments: [
        {
          filename: `Policy_${normalized.policyNumber}.pdf`,
          content: pdfBuffer,
          contentType: "application/pdf",
        },
      ],
    });

    await logRef.set({
      policyId,
      recipientEmail: resolvedRecipient,
      subject,
      sentAt: FieldValue.serverTimestamp(),
      status: "sent",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    await db.collection("policies").doc(policyId).set({
      policyEmailSentAt: FieldValue.serverTimestamp(),
      policyEmailRecipient: resolvedRecipient,
    }, {merge: true});

    return {success: true, skipped: false, recipientEmail: resolvedRecipient};
  } catch (error) {
    await logRef.set({
      policyId,
      recipientEmail: resolvedRecipient,
      status: "failed",
      error: error.message || String(error),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}

exports.sendPolicyEmail = onCall(
    {
      region: "us-central1",
      invoker: "public",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const {
        policyId,
        policyNumber,
        recipientEmail,
        recipientName,
        policyData,
      } = request.data || {};

      if (!policyId || !policyData) {
        throw new HttpsError(
            "invalid-argument",
            "Missing required fields: policyId and policyData",
        );
      }

      return await sendPolicyEmailForPolicy({
        policyId,
        policyNumber,
        recipientEmail,
        recipientName,
        policyData,
      });
    },
);

exports.generatePolicyPDF = onCall(
    {
      region: "us-central1",
      invoker: "public",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const {policyId, policyNumber, policyData} = request.data || {};
      if (!policyId || !policyData) {
        throw new HttpsError(
            "invalid-argument",
            "Missing required fields: policyId and policyData",
        );
      }

      return await generatePolicyPDFForPolicy({
        policyId,
        policyNumber,
        policyData,
      });
    },
);

exports.checkExpiringPolicies = onSchedule(
    {
      region: "us-central1",
      schedule: "0 0 * * *",
      timeZone: "UTC",
    },
    async () => {
      const transporter = createTransporter();
      if (!transporter) {
        logger.warn("SENDGRID_API_KEY not configured, skipping renewal reminders");
        return null;
      }

      const thirtyDaysFromNow = new Date();
      thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

      const expiringPolicies = await db
          .collection("policies")
          .where("status", "==", "active")
          .where("expirationDate", "<=", thirtyDaysFromNow.toISOString())
          .get();

      logger.info("Found expiring policies", {count: expiringPolicies.size});

      await Promise.all(expiringPolicies.docs.map(async (docSnap) => {
        const policy = normalizePolicyData(docSnap.data());
        const recipient = policy.owner.email;
        if (!recipient) {
          return;
        }

        const expirationDate = toDate(policy.expirationDate) || new Date();
        const daysUntilExpiration = Math.max(
            0,
            Math.floor((expirationDate - new Date()) / (1000 * 60 * 60 * 24)),
        );

        await transporter.sendMail({
          from: "Clovara <noreply@clovara.com>",
          to: recipient,
          subject: `Policy Renewal Reminder - ${daysUntilExpiration} days remaining`,
          html: getRenewalReminderTemplate(policy, daysUntilExpiration),
        });
      }));

      return {success: true, count: expiringPolicies.size};
    },
);

function getRenewalReminderTemplate(policy, daysRemaining) {
  return `
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #FEF3C7; padding: 20px; border-radius: 8px; border-left: 4px solid #F59E0B;">
        <h2 style="color: #92400E;">Policy Renewal Reminder</h2>
        <p>Your pet insurance policy for <strong>${policy.pet.name}</strong> is expiring in <strong>${daysRemaining} days</strong>.</p>
        <p><strong>Policy Number:</strong> ${policy.policyNumber}</p>
        <p><strong>Expiration Date:</strong> ${formatDate(policy.expirationDate)}</p>
        <div style="margin: 30px 0; text-align: center;">
          <a href="https://pet-underwriter-ai.web.app" 
             style="display: inline-block; background-color: #F59E0B; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
            Review Policy
          </a>
        </div>
        <p>Don&apos;t let your coverage lapse. Review your policy before it expires.</p>
      </div>
    </body>
    </html>
  `;
}

exports.generatePolicyPDFBuffer = generatePolicyPDFBuffer;
exports.generatePolicyPDFForPolicy = generatePolicyPDFForPolicy;
exports.sendPolicyEmailForPolicy = sendPolicyEmailForPolicy;
exports.normalizePolicyData = normalizePolicyData;

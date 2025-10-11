const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const PDFDocument = require('pdfkit');
const { Storage } = require('@google-cloud/storage');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = new Storage();

// Configure email transporter (using SendGrid as example)
const transporter = nodemailer.createTransporter({
  host: 'smtp.sendgrid.net',
  port: 587,
  auth: {
    user: 'apikey',
    pass: functions.config().sendgrid?.key || process.env.SENDGRID_API_KEY,
  },
});

/**
 * Cloud Function to send policy email with PDF attachment
 */
exports.sendPolicyEmail = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const {
      policyId,
      policyNumber,
      recipientEmail,
      recipientName,
      policyData,
    } = data;

    // Validate required fields
    if (!policyId || !recipientEmail || !policyData) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    // Generate PDF
    const pdfBuffer = await generatePolicyPDFBuffer(policyData);

    // Email content
    const mailOptions = {
      from: 'Pet Underwriter AI <noreply@petunderwriter.ai>',
      to: recipientEmail,
      subject: `Your Pet Insurance Policy - ${policyNumber}`,
      html: getPolicyEmailTemplate(recipientName, policyData),
      attachments: [
        {
          filename: `Policy_${policyNumber}.pdf`,
          content: pdfBuffer,
          contentType: 'application/pdf',
        },
      ],
    };

    // Send email
    await transporter.sendMail(mailOptions);

    // Log email sent
    await db.collection('email_logs').add({
      policyId,
      recipientEmail,
      subject: mailOptions.subject,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
    });

    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending policy email:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Cloud Function to generate policy PDF
 */
exports.generatePolicyPDF = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { policyId, policyNumber, policyData } = data;

    if (!policyId || !policyData) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    // Generate PDF
    const pdfBuffer = await generatePolicyPDFBuffer(policyData);

    // Upload to Firebase Storage
    const bucket = storage.bucket(functions.config().firebase?.storage_bucket);
    const fileName = `policies/${policyId}/${policyNumber}.pdf`;
    const file = bucket.file(fileName);

    await file.save(pdfBuffer, {
      metadata: {
        contentType: 'application/pdf',
        metadata: {
          policyId,
          policyNumber,
          createdAt: new Date().toISOString(),
        },
      },
    });

    // Make file publicly accessible (or use signed URL for private access)
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    // Update policy document with PDF URL
    await db.collection('policies').doc(policyId).update({
      pdfUrl: url,
      pdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, pdfUrl: url };
  } catch (error) {
    console.error('Error generating policy PDF:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Generate PDF buffer from policy data
 */
async function generatePolicyPDFBuffer(policyData) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ size: 'LETTER', margin: 50 });
      const buffers = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfBuffer = Buffer.concat(buffers);
        resolve(pdfBuffer);
      });

      // Header
      doc
        .fontSize(24)
        .fillColor('#1E40AF')
        .text('Pet Insurance Policy', { align: 'center' })
        .moveDown();

      doc
        .fontSize(12)
        .fillColor('#000000')
        .text(`Policy Number: ${policyData.policyNumber}`, { align: 'center' })
        .moveDown(2);

      // Policy Holder Information
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Policy Holder Information')
        .moveDown(0.5);

      doc
        .fontSize(12)
        .fillColor('#000000')
        .text(`Name: ${policyData.owner.firstName} ${policyData.owner.lastName}`)
        .text(`Email: ${policyData.owner.email}`)
        .text(`Phone: ${policyData.owner.phone}`)
        .text(
          `Address: ${policyData.owner.addressLine1}${
            policyData.owner.addressLine2 ? ', ' + policyData.owner.addressLine2 : ''
          }`
        )
        .text(
          `         ${policyData.owner.city}, ${policyData.owner.state} ${policyData.owner.zipCode}`
        )
        .moveDown(2);

      // Pet Information
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Insured Pet Information')
        .moveDown(0.5);

      doc
        .fontSize(12)
        .fillColor('#000000')
        .text(`Name: ${policyData.pet.name}`)
        .text(`Species: ${policyData.pet.species}`)
        .text(`Breed: ${policyData.pet.breed}`)
        .text(`Age: ${policyData.pet.age} years`)
        .text(`Gender: ${policyData.pet.gender}`)
        .text(`Weight: ${policyData.pet.weight} lbs`)
        .moveDown(2);

      // Coverage Details
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Coverage Details')
        .moveDown(0.5);

      doc
        .fontSize(12)
        .fillColor('#000000')
        .text(`Plan: ${policyData.plan.name}`)
        .text(`Monthly Premium: $${policyData.plan.monthlyPremium.toFixed(2)}`)
        .text(`Annual Premium: $${(policyData.plan.monthlyPremium * 12).toFixed(2)}`)
        .text(`Annual Deductible: $${policyData.plan.annualDeductible.toFixed(0)}`)
        .text(`Reimbursement: ${100 - policyData.plan.coPayPercentage}%`)
        .text(`Annual Maximum: $${policyData.plan.maxAnnualCoverage.toLocaleString()}`)
        .moveDown(2);

      // Coverage Period
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Coverage Period')
        .moveDown(0.5);

      doc
        .fontSize(12)
        .fillColor('#000000')
        .text(
          `Effective Date: ${new Date(policyData.effectiveDate).toLocaleDateString()}`
        )
        .text(
          `Expiration Date: ${new Date(policyData.expirationDate).toLocaleDateString()}`
        )
        .moveDown(2);

      // Covered Benefits
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Covered Benefits')
        .moveDown(0.5);

      doc.fontSize(12).fillColor('#000000');
      policyData.plan.features.forEach((feature) => {
        doc.text(`• ${feature}`);
      });
      doc.moveDown(2);

      // Exclusions
      doc
        .fontSize(16)
        .fillColor('#1E40AF')
        .text('Policy Exclusions')
        .moveDown(0.5);

      doc.fontSize(12).fillColor('#000000');
      policyData.plan.exclusions.forEach((exclusion) => {
        doc.text(`• ${exclusion}`);
      });
      doc.moveDown(2);

      // Footer
      doc
        .fontSize(10)
        .fillColor('#666666')
        .text(
          'This policy is subject to the terms and conditions outlined in your full policy documents.',
          { align: 'center' }
        )
        .text('For questions or claims, contact support@petunderwriter.ai', {
          align: 'center',
        })
        .moveDown();

      doc
        .fontSize(8)
        .text(`Document generated on ${new Date().toLocaleDateString()}`, {
          align: 'center',
        });

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Email template for policy confirmation
 */
function getPolicyEmailTemplate(recipientName, policyData) {
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
        <h1>🎉 Your Policy is Active!</h1>
        <p>Welcome to Pet Underwriter AI</p>
      </div>
      
      <div class="content">
        <p>Dear ${recipientName || 'Valued Customer'},</p>
        
        <p>Congratulations! Your pet insurance policy is now <strong>active</strong> and your furry friend is protected.</p>
        
        <div class="policy-box">
          <h2>Policy Details</h2>
          <p><strong>Policy Number:</strong> <span class="highlight">${policyData.policyNumber}</span></p>
          <p><strong>Pet Name:</strong> ${policyData.pet.name}</p>
          <p><strong>Plan:</strong> ${policyData.plan.name}</p>
          <p><strong>Monthly Premium:</strong> $${policyData.plan.monthlyPremium.toFixed(2)}</p>
          <p><strong>Coverage Start:</strong> ${new Date(policyData.effectiveDate).toLocaleDateString()}</p>
        </div>
        
        <h3>What's Next?</h3>
        <ol>
          <li><strong>Review Your Policy:</strong> Your complete policy document is attached to this email.</li>
          <li><strong>Save Your Documents:</strong> Keep this email and the attached PDF for your records.</li>
          <li><strong>Schedule a Checkup:</strong> Visit your vet and start using your coverage!</li>
          <li><strong>File Claims Easily:</strong> Use our mobile app or website to submit claims.</li>
        </ol>
        
        <div style="text-align: center;">
          <a href="https://petunderwriter.ai/dashboard" class="button">Go to Dashboard</a>
        </div>
        
        <div class="policy-box">
          <h3>Need Help?</h3>
          <p>Our support team is here for you 24/7:</p>
          <ul>
            <li>📧 Email: support@petunderwriter.ai</li>
            <li>📱 Phone: 1-800-PET-CARE</li>
            <li>💬 Live Chat: Available on our website</li>
          </ul>
        </div>
        
        <p>Thank you for choosing Pet Underwriter AI to protect your beloved pet!</p>
        
        <p>Best regards,<br>
        <strong>The Pet Underwriter AI Team</strong></p>
      </div>
      
      <div class="footer">
        <p>Pet Underwriter AI | Protecting Pets, Empowering Owners</p>
        <p>This email was sent to ${policyData.owner.email}</p>
        <p><a href="https://petunderwriter.ai/privacy">Privacy Policy</a> | <a href="https://petunderwriter.ai/terms">Terms of Service</a></p>
      </div>
    </body>
    </html>
  `;
}

/**
 * Scheduled function to check for expiring policies
 */
exports.checkExpiringPolicies = functions.pubsub
  .schedule('0 0 * * *') // Run daily at midnight
  .onRun(async (context) => {
    try {
      const thirtyDaysFromNow = new Date();
      thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

      const expiringPolicies = await db
        .collection('policies')
        .where('status', '==', 'active')
        .where('expirationDate', '<=', thirtyDaysFromNow.toISOString())
        .get();

      console.log(`Found ${expiringPolicies.size} expiring policies`);

      const emailPromises = expiringPolicies.docs.map(async (doc) => {
        const policy = doc.data();
        const daysUntilExpiration = Math.floor(
          (new Date(policy.expirationDate) - new Date()) / (1000 * 60 * 60 * 24)
        );

        // Send renewal reminder email
        await transporter.sendMail({
          from: 'Pet Underwriter AI <noreply@petunderwriter.ai>',
          to: policy.owner.email,
          subject: `Policy Renewal Reminder - ${daysUntilExpiration} days remaining`,
          html: getRenewalReminderTemplate(policy, daysUntilExpiration),
        });

        console.log(`Sent renewal reminder to ${policy.owner.email}`);
      });

      await Promise.all(emailPromises);

      return { success: true, count: expiringPolicies.size };
    } catch (error) {
      console.error('Error checking expiring policies:', error);
      throw error;
    }
  });

function getRenewalReminderTemplate(policy, daysRemaining) {
  return `
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #FEF3C7; padding: 20px; border-radius: 8px; border-left: 4px solid #F59E0B;">
        <h2 style="color: #92400E;">⏰ Policy Renewal Reminder</h2>
        <p>Your pet insurance policy for <strong>${policy.pet.name}</strong> is expiring in <strong>${daysRemaining} days</strong>.</p>
        <p><strong>Policy Number:</strong> ${policy.policyNumber}</p>
        <p><strong>Expiration Date:</strong> ${new Date(policy.expirationDate).toLocaleDateString()}</p>
        <div style="margin: 30px 0; text-align: center;">
          <a href="https://petunderwriter.ai/renew/${policy.policyId}" 
             style="display: inline-block; background-color: #F59E0B; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
            Renew Now
          </a>
        </div>
        <p>Don't let your coverage lapse! Renew today to ensure continuous protection for your pet.</p>
      </div>
    </body>
    </html>
  `;
}

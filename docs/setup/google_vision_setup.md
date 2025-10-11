# Google Cloud Vision API Setup Guide

## Quick Setup (5 minutes)

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Name: `petuwrite-ocr` or similar
4. Click "Create"

### Step 2: Enable Vision API

1. In the Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Cloud Vision API"
3. Click **Enable**

### Step 3: Create API Key

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **API Key**
3. Copy the generated key (starts with `AIza...`)
4. **Security:** Click "Restrict Key"
   - Application restrictions: None (or IP addresses if server-side)
   - API restrictions: Restrict to "Cloud Vision API"
   - Save

### Step 4: Add to .env File

Add to your `.env` file:
```bash
GOOGLE_VISION_API_KEY=AIzaSy...YOUR_KEY_HERE...
```

### Step 5: Test Integration

```dart
import 'package:pet_underwriter_ai/services/claim_document_ai_service.dart';

void testOCR() async {
  final service = ClaimDocumentAIService(
    ocrProvider: OCRProvider.googleVision,
  );
  
  final analysis = await service.analyzeDocument(
    filePath: '/path/to/test_invoice.jpg',
    claimId: 'test',
    documentId: 'test',
  );
  
  print('Success: ${!analysis.hasError}');
  print('Text length: ${analysis.extractedText.length}');
  print('Provider: ${analysis.providerName}');
}
```

---

## Pricing (As of 2025)

### Vision API Costs
- **First 1,000 units/month:** FREE
- **1,001 - 5,000,000:** $1.50 per 1,000 units
- **5,000,001+:** $0.60 per 1,000 units

### Unit Definition
- 1 image = 1 unit
- Maximum 75 features per request

### Example Monthly Costs

| Claims/Month | Documents/Claim | Total Units | Cost |
|--------------|----------------|-------------|------|
| 100 | 2 | 200 | FREE |
| 1,000 | 2 | 2,000 | $1.50 |
| 5,000 | 2 | 10,000 | $15.00 |
| 10,000 | 3 | 30,000 | $45.00 |

---

## Billing Setup

### Enable Billing (Required after free tier)

1. Go to **Billing** in Cloud Console
2. Link a payment method
3. Set up budget alerts:
   - Budget: $50/month (recommended start)
   - Alert at 50%, 90%, 100%

### Monitor Usage

1. Go to **APIs & Services** → **Dashboard**
2. View "Cloud Vision API" usage
3. Track daily requests
4. Set quotas if needed

---

## Security Best Practices

### 1. Restrict API Key

**Application Restrictions:**
- Server-side: IP address restriction
- Mobile app: Use Firebase Functions proxy

**API Restrictions:**
- Only enable Cloud Vision API
- Disable unused APIs

### 2. Use Environment Variables

```bash
# .env (never commit!)
GOOGLE_VISION_API_KEY=AIza...

# .gitignore
.env
.env.local
```

### 3. Rotate Keys

- Rotate every 90 days
- Create new key before deleting old
- Test with new key before switching
- Delete old key after transition

### 4. Firebase Functions Proxy (Recommended)

Instead of client-side API calls, use server-side:

```javascript
// functions/index.js
const vision = require('@google-cloud/vision');
const client = new vision.ImageAnnotatorClient();

exports.analyzeDocument = functions.https.onCall(async (data, context) => {
  // Verify auth
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated');
  }
  
  const imageUrl = data.imageUrl;
  
  // Call Vision API
  const [result] = await client.documentTextDetection(imageUrl);
  const fullText = result.fullTextAnnotation?.text || '';
  
  return { text: fullText };
});
```

**Benefits:**
- No exposed API keys
- Better security
- Centralized billing
- Rate limiting

---

## Image Optimization

### Best Practices for OCR

**Image Quality:**
- Resolution: 300+ DPI
- Format: JPEG, PNG, PDF
- Size: <10MB (ideal: <2MB)
- Color: Color or grayscale (not black/white)

**Pre-processing (Optional):**
```dart
import 'package:image/image.dart' as img;

Future<File> optimizeForOCR(File originalFile) async {
  // Load image
  final bytes = await originalFile.readAsBytes();
  final image = img.decodeImage(bytes)!;
  
  // Resize if too large (max 4096px)
  final maxDim = 4096;
  if (image.width > maxDim || image.height > maxDim) {
    final resized = img.copyResize(
      image,
      width: image.width > image.height ? maxDim : null,
      height: image.height > image.width ? maxDim : null,
    );
    
    // Save optimized
    final optimized = File('${originalFile.path}_opt.jpg');
    await optimized.writeAsBytes(img.encodeJpg(resized, quality: 85));
    return optimized;
  }
  
  return originalFile;
}
```

---

## Troubleshooting

### Error: "API key not valid"
- Check key in .env matches Cloud Console
- Verify key restrictions don't block request
- Ensure Vision API is enabled
- Try creating new key

### Error: "Quota exceeded"
- Check billing is enabled
- View quota in Cloud Console
- Request quota increase if needed
- Consider caching results

### Error: "No text detected"
- Check image quality (blur, resolution)
- Ensure text is readable
- Try different image format
- Verify image isn't corrupted

### Low Accuracy
- Improve image resolution
- Better lighting in photos
- Flatten wrinkled documents
- Use scanner instead of camera

---

## Alternative: AWS Textract

If you prefer AWS:

### Setup
1. Create AWS account
2. Enable Textract service
3. Create IAM user with Textract permissions
4. Generate access keys

### Configuration
```bash
# .env
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

### Usage
```dart
final service = ClaimDocumentAIService(
  ocrProvider: OCRProvider.awsTextract,
);
```

**Note:** AWS Textract implementation pending in service.

---

## Testing Without API

Use Mock mode for development:

```dart
final service = ClaimDocumentAIService(
  ocrProvider: OCRProvider.mock,
);
```

**Mock data includes:**
- Realistic vet invoice
- Multiple procedures
- ICD-10 and CPT codes
- Itemized billing
- Total: $1,578.68

---

## Production Checklist

- [ ] Google Cloud project created
- [ ] Vision API enabled
- [ ] API key created and restricted
- [ ] Key added to .env
- [ ] .env in .gitignore
- [ ] Billing enabled (after free tier)
- [ ] Budget alerts configured
- [ ] API key rotation scheduled
- [ ] Firebase Functions proxy implemented (recommended)
- [ ] Image optimization implemented
- [ ] Error handling tested
- [ ] Usage monitoring dashboard setup

---

**Next Steps:** Test with real documents, monitor accuracy, adjust confidence thresholds

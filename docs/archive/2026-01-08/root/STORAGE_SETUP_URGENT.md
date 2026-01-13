# URGENT: Firebase Storage Setup Required

## ⚠️ Firebase Storage Not Enabled

Your upload is failing because Firebase Storage hasn't been set up on your project yet.

## Quick Fix Steps

### Step 1: Enable Firebase Storage

1. Go to: https://console.firebase.google.com/project/pet-underwriter-ai/storage
2. Click **"Get Started"** button
3. Click **"Next"** on the security rules dialog (we'll deploy our custom rules later)
4. Select a location for your storage (choose the same region as your Firestore)
5. Click **"Done"**

### Step 2: Deploy Storage Rules

After enabling Storage in the console, deploy the rules:

```bash
firebase deploy --only storage
```

### Step 3: Configure CORS

Since you're on localhost, you need to configure CORS. You have two options:

#### Option A: Using Firebase Console (Recommended - No extra tools needed)

1. After enabling Storage, go to the Storage tab in Firebase Console
2. Click on your bucket name
3. Go to the **Configuration** tab
4. Look for CORS settings (may need to use Google Cloud Console - link provided in Firebase)

#### Option B: Using gsutil (Requires Google Cloud SDK)

First, install Google Cloud SDK if you haven't:
```bash
# macOS
brew install --cask google-cloud-sdk

# Then authenticate
gcloud auth login
gcloud config set project pet-underwriter-ai
```

Then apply CORS:
```bash
gsutil cors set cors.json gs://pet-underwriter-ai.appspot.com
```

### Step 4: Alternative - Use Emulator for Development

If you want to test locally without deploying, you can use Firebase Emulator:

```bash
# Start the emulators
firebase emulators:start --only storage

# Update your Firebase initialization to use emulator
```

Then in your Flutter web code, add:
```dart
// In your Firebase initialization
if (kDebugMode) {
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
}
```

## Recommended Approach for Now

**For immediate testing:**

1. Enable Firebase Storage in console (Step 1 above)
2. Deploy storage rules: `firebase deploy --only storage`
3. For CORS, the easiest way is to:
   - Go to https://console.cloud.google.com/
   - Select your project
   - Go to Cloud Storage
   - Click on your bucket
   - Use the "Edit CORS Configuration" option in the bucket settings

**The CORS JSON to paste:**
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "POST", "PUT", "DELETE", "HEAD"],
    "maxAgeSeconds": 3600,
    "responseHeader": ["Content-Type", "Authorization", "Content-Length", "User-Agent", "x-goog-resumable"]
  }
]
```

## What Happens Next

Once Storage is enabled and CORS is configured:
- ✅ Document uploads will work from localhost
- ✅ Files will be stored in Firebase Storage
- ✅ URLs will be saved to Firestore
- ✅ Users can view uploaded documents

## Security Note

The current CORS config (`"origin": ["*"]`) allows all origins. This is fine for development, but **before going to production**, update it to only allow your actual domains:

```json
{
  "origin": [
    "https://your-domain.com",
    "https://pet-underwriter-ai.web.app",
    "https://pet-underwriter-ai.firebaseapp.com"
  ],
  ...
}
```

## Files Created

- ✅ `storage.rules` - Security rules for Storage
- ✅ `cors.json` - CORS configuration
- ✅ `firebase.json` - Updated with storage config
- ✅ `deploy_storage.sh` - Deployment helper script
- ✅ `STORAGE_UPLOAD_FIX.md` - Detailed fix guide
- ✅ `STORAGE_SETUP_URGENT.md` - This file

## Next Steps

1. **Right now:** Enable Storage in Firebase Console
2. **Then:** Deploy storage rules
3. **Then:** Configure CORS
4. **Finally:** Test the upload again

## Need Help?

If you get stuck, let me know which step you're on!

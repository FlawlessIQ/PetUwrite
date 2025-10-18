# Firebase Storage Upload Fix

## Problem
Claims document uploads were failing due to:
1. Missing Firebase Storage security rules
2. CORS configuration not set for localhost development
3. Firestore permission errors

## Solution

### Step 1: Deploy Storage Rules

Deploy the storage rules to allow authenticated users to upload files:

```bash
firebase deploy --only storage
```

This will deploy the `storage.rules` file which allows:
- Authenticated users to upload claim documents (max 10MB, images/PDFs)
- Authenticated users to upload pet images (max 5MB, images only)
- Authenticated users to upload policy documents (max 10MB, images/PDFs)

### Step 2: Configure CORS for Firebase Storage

CORS (Cross-Origin Resource Sharing) needs to be configured to allow localhost uploads.

#### Option A: Using Google Cloud Console (Easiest)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `pet-underwriter-ai`
3. Navigate to **Cloud Storage** → **Browser**
4. Find your bucket: `pet-underwriter-ai.firebasestorage.app` or `pet-underwriter-ai.appspot.com`
5. Click on the bucket name
6. Go to **Permissions** tab
7. Under **CORS configuration**, click **Edit CORS configuration**
8. Paste this configuration:

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

9. Click **Save**

#### Option B: Using gsutil command line (Requires Google Cloud SDK)

If you have `gsutil` installed:

```bash
# Find your bucket name first
firebase projects:list

# Then apply CORS configuration
gsutil cors set cors.json gs://pet-underwriter-ai.firebasestorage.app
```

**Note:** For production, you should restrict the `origin` to your deployed domain instead of using `"*"`.

### Step 3: Verify the Fix

1. Restart your Flutter web app:
```bash
flutter run -d chrome
```

2. Try uploading a document to a claim
3. Check browser console - you should no longer see CORS errors

## Testing

After deploying:

1. Navigate to a pending claim
2. Click "Upload Documents"
3. Select a file (JPG, PNG, or PDF)
4. The upload should complete successfully
5. The file URL should be saved to Firestore

## Files Modified

- ✅ `storage.rules` - New Firebase Storage security rules
- ✅ `cors.json` - CORS configuration for Storage bucket
- ✅ `firebase.json` - Updated to include storage rules
- ✅ `deploy_storage.sh` - Helper script for deployment

## Troubleshooting

### Still seeing CORS errors?
- Make sure you applied CORS configuration to the correct bucket
- Try clearing browser cache and restarting the app
- Verify storage rules were deployed: `firebase deploy --only storage`

### Permission denied errors?
- Make sure you're signed in (authenticated) in the app
- Check that storage rules allow the path you're uploading to
- Verify the file size and type match the rules

### Upload succeeds but file not showing?
- Check the Firestore console to see if the URL was saved
- Verify the claim document has `attachments` array updated
- Check browser Network tab for actual upload status

## Security Notes

### For Production:
Update `cors.json` to restrict origins:
```json
{
  "origin": ["https://your-domain.com", "https://your-domain.firebaseapp.com"],
  ...
}
```

And redeploy CORS configuration.

### Storage Rules:
The current rules allow any authenticated user to upload to claims. For stricter security, you can modify `storage.rules` to check ownership:

```javascript
match /claims/{claimId}/{fileName} {
  allow read: if request.auth != null;
  allow write: if request.auth != null 
               && request.auth.uid == resource.metadata.ownerId;
}
```

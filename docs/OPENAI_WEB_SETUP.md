# OpenAI API Key Setup for Web Deployment

## Overview

The PetUwrite web app now has full OpenAI API integration enabled, allowing Pawla (the conversational AI) to work on the live website at https://pet-underwriter-ai.web.app.

## How It Works

### Local Development
- API key is stored in `.env` file (not committed to git)
- Loaded via `flutter_dotenv` package
- Works seamlessly with hot reload

### Web Deployment
- API key is passed as a **compile-time constant** using `--dart-define`
- Embedded directly into the compiled JavaScript
- No runtime environment variable loading needed

## Architecture

```dart
// Priority order for API key loading:
factory ConversationalAIService({String? apiKey}) {
  // 1. Use provided API key (for web deployment via --dart-define)
  if (apiKey != null && apiKey.isNotEmpty) {
    return ConversationalAIService._internal(apiKey);
  }
  
  // 2. Try loading from .env (for local development)
  try {
    key = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (key.isNotEmpty) {
      return ConversationalAIService._internal(key);
    }
  } catch (e) { ... }
  
  // 3. Fallback mode (simplified questions without AI)
  return ConversationalAIService._internal('mock-key-for-fallback-mode');
}
```

## Deployment

### Quick Deploy (Recommended)
```bash
./deploy_web.sh
```

This script:
1. Loads API key from `.env` file
2. Builds web app with `--dart-define=OPENAI_API_KEY=$OPENAI_API_KEY`
3. Deploys to Firebase Hosting

### Manual Deploy
```bash
# Load API key from .env
export $(grep -v '^#' .env | xargs)

# Build with API key
flutter build web --release --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY

# Deploy
firebase deploy --only hosting
```

## Security Considerations

### ⚠️ Important Notes

1. **API Key Visibility**: The API key is embedded in the compiled JavaScript. While obfuscated, it's technically visible to determined users who inspect the compiled code.

2. **Rate Limiting**: OpenAI API keys can be rate-limited and have usage quotas. Monitor usage in your OpenAI dashboard.

3. **Recommended for Production**: For a more secure production setup, consider:
   - **Firebase Cloud Functions**: Proxy API calls through a backend function
   - **API Gateway**: Use a secure backend service to handle OpenAI requests
   - **Rate Limiting**: Implement per-user rate limits in your app

### Future Enhancement: Cloud Functions

For production, create a secure proxy:

```javascript
// functions/openai-proxy.js
exports.chatCompletion = functions.https.onCall(async (data, context) => {
  // Verify user authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Rate limit per user
  // ... implement rate limiting ...
  
  // Call OpenAI with server-side API key
  const openai = new OpenAI({
    apiKey: functions.config().openai.key,
  });
  
  return await openai.chat.completions.create(data.request);
});
```

## Testing

### Test Locally
```bash
flutter run -d chrome
```

### Test Deployed Version
1. Visit https://pet-underwriter-ai.web.app
2. Click "Get a Quote"
3. Verify Pawla responds with natural, AI-enhanced questions
4. Check browser console for: `✅ OpenAI API key provided directly`

### Verify API Usage
- Monitor usage: https://platform.openai.com/usage
- Check for errors in Firebase Console logs

## Troubleshooting

### Build Fails
```
Error: Failed to compile application for the Web.
```
**Solution**: Make sure API key doesn't contain special characters that break the shell command. Wrap in quotes if needed.

### API Key Not Working
Check console for:
- `✅ OpenAI API key provided directly` → Working!
- `⚠️ OPENAI_API_KEY not found, conversations will use fallback responses` → Key not loaded

### API Quota Exceeded
```
Error: You exceeded your current quota
```
**Solution**: 
1. Check OpenAI billing: https://platform.openai.com/account/billing
2. Add payment method or upgrade plan
3. Implement fallback mode for graceful degradation

## Files Modified

1. **lib/services/conversational_ai_service.dart**
   - Factory pattern with priority-based key loading
   - Graceful fallback when key unavailable

2. **lib/screens/conversational_quote_flow.dart**
   - Uses `String.fromEnvironment('OPENAI_API_KEY')` to read compile-time constant
   - Passes key to `ConversationalAIService`

3. **deploy_web.sh**
   - Automated deployment script
   - Loads key from .env and builds with --dart-define

## Cost Estimation

**GPT-4o-mini pricing** (as of Oct 2024):
- Input: $0.15 per 1M tokens
- Output: $0.60 per 1M tokens

**Typical quote conversation**:
- ~10 messages × ~200 tokens each = ~2,000 tokens
- Cost per quote: ~$0.001 (one-tenth of a penny)
- 1,000 quotes = ~$1.00

**Monitoring**: Set up billing alerts in OpenAI dashboard.

## Next Steps

- [ ] Monitor API usage and costs
- [ ] Implement rate limiting per user
- [ ] Consider Cloud Functions for production security
- [ ] Add error reporting for API failures
- [ ] Test breed recognition and validation features
- [ ] Verify empathetic responses for serious conditions

---

**Last Updated**: October 11, 2025  
**Deployment URL**: https://pet-underwriter-ai.web.app  
**OpenAI Model**: gpt-4o-mini

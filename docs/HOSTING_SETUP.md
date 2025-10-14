# Firebase Hosting Setup - PetUwrite

**Date:** October 11, 2025  
**Status:** ✅ Deployed  
**Hosting URL:** https://pet-underwriter-ai.web.app

---

## Configuration

### Firebase JSON
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=7200"
          }
        ]
      },
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=3600"
          }
        ]
      }
    ]
  }
}
```

### Key Settings
- **Public directory:** `build/web` (Flutter's web build output)
- **Single-page app:** Yes (all routes rewrite to `/index.html`)
- **Cache headers:** Images (2 hours), JS/CSS (1 hour)

---

## Deployment Commands

### Build & Deploy (Production)
```bash
# Build for production
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Quick Deploy Script
```bash
# One-liner for build + deploy
flutter build web --release && firebase deploy --only hosting
```

### Deploy Specific Functions + Hosting
```bash
firebase deploy --only hosting,functions
```

### Deploy Everything
```bash
firebase deploy
```

---

## GitHub Actions Workflow

A GitHub Actions workflow was created for automatic deployments:

**File:** `.github/workflows/firebase-hosting-pull-request.yml`

This workflow:
- ✅ Triggers on pull requests
- ✅ Builds the Flutter web app
- ✅ Deploys to a preview channel
- ✅ Uses service account: `github-action-1074043298`

**Note:** Main branch auto-deployment was disabled. To enable:
```bash
firebase init hosting:github
```

---

## Hosting URLs

### Production
- **URL:** https://pet-underwriter-ai.web.app
- **Alternate:** https://pet-underwriter-ai.firebaseapp.com

### Custom Domain (Future)
To add a custom domain:
```bash
firebase hosting:channel:deploy custom-domain
```

Then configure in Firebase Console:
1. Go to Hosting section
2. Click "Add custom domain"
3. Follow DNS setup instructions

---

## Build Configuration

### Flutter Web Build Options

**Standard Release Build:**
```bash
flutter build web --release
```

**With Specific Renderer:**
```bash
flutter build web --release --web-renderer canvaskit
flutter build web --release --web-renderer html
```

**With Source Maps (Debugging):**
```bash
flutter build web --release --source-maps
```

**Profile Build (Performance Testing):**
```bash
flutter build web --profile
```

---

## Cache & Performance

### Current Cache Headers
- **Images:** 2 hours (`max-age=7200`)
- **JS/CSS:** 1 hour (`max-age=3600`)
- **HTML:** No cache (always fetch fresh)

### To Clear Hosting Cache
```bash
firebase hosting:clone pet-underwriter-ai:live pet-underwriter-ai:temp
firebase hosting:channel:delete temp
```

---

## Preview Channels

### Create Preview Channel
```bash
# Build first
flutter build web --release

# Deploy to preview channel
firebase hosting:channel:deploy preview-name
```

### List Channels
```bash
firebase hosting:channel:list
```

### Delete Channel
```bash
firebase hosting:channel:delete preview-name
```

---

## Rollback & Version Management

### View Previous Versions
```bash
firebase hosting:releases:list
```

### Rollback to Previous Version
1. Go to Firebase Console > Hosting
2. Click on "Release history"
3. Click "Rollback" on desired version

Or via CLI:
```bash
firebase hosting:rollback
```

---

## Monitoring & Analytics

### View Hosting Metrics
```bash
firebase hosting:metrics
```

### Check Hosting Status
```bash
firebase hosting:status
```

---

## Troubleshooting

### Build Errors
```bash
# Clean build
flutter clean
flutter pub get
flutter build web --release
```

### Deployment Errors
```bash
# Re-authenticate
firebase login --reauth

# Check project
firebase use

# Deploy with verbose logging
firebase deploy --only hosting --debug
```

### 404 Errors on Routes
Ensure `rewrites` section in `firebase.json` includes:
```json
"rewrites": [
  {
    "source": "**",
    "destination": "/index.html"
  }
]
```

### Assets Not Loading
Check that `assets` are included in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/
    - assets/images/
```

---

## Environment Variables

### Production Environment
Set in `.env` file:
```bash
OPENAI_API_KEY=your_key_here
FIREBASE_WEB_API_KEY=your_key_here
```

### Build with Environment
```bash
flutter build web --release --dart-define=ENV=production
```

---

## CI/CD Integration

### GitHub Actions Secret
A service account was created and stored as:
```
FIREBASE_SERVICE_ACCOUNT_PET_UNDERWRITER_AI
```

### Manual Workflow Trigger
```bash
# Push to trigger workflow
git add .
git commit -m "Deploy to Firebase Hosting"
git push origin main
```

---

## Best Practices

### Before Each Deploy
1. ✅ Test locally: `flutter run -d chrome`
2. ✅ Run tests: `flutter test`
3. ✅ Build for release: `flutter build web --release`
4. ✅ Preview build: Open `build/web/index.html` in browser
5. ✅ Deploy: `firebase deploy --only hosting`

### Performance Optimization
1. Enable tree-shaking (default in release mode)
2. Compress images before adding to assets
3. Use WebP format for images when possible
4. Lazy load routes with Navigator 2.0
5. Use `const` widgets where possible

### Security
1. Never commit `.env` files
2. Use Firebase App Check for production
3. Set appropriate CORS policies
4. Enable Firestore security rules
5. Monitor Firebase Console for anomalies

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `flutter build web --release` | Build production web app |
| `firebase deploy --only hosting` | Deploy to hosting |
| `firebase hosting:channel:deploy dev` | Deploy to preview channel |
| `firebase hosting:releases:list` | View deployment history |
| `firebase hosting:rollback` | Rollback to previous version |
| `firebase login` | Authenticate CLI |
| `firebase use pet-underwriter-ai` | Switch projects |

---

## Support

- **Firebase Console:** https://console.firebase.google.com/project/pet-underwriter-ai
- **Hosting Dashboard:** https://console.firebase.google.com/project/pet-underwriter-ai/hosting
- **Firebase Documentation:** https://firebase.google.com/docs/hosting
- **Flutter Web Docs:** https://docs.flutter.dev/deployment/web

---

## Next Steps

- [ ] Set up custom domain (e.g., petuwrite.com)
- [ ] Configure CDN caching strategy
- [ ] Enable Firebase App Check
- [ ] Set up monitoring and alerts
- [ ] Configure automatic GitHub deployments on merge to main
- [ ] Add staging environment with separate preview channel
- [ ] Set up A/B testing with Firebase Remote Config

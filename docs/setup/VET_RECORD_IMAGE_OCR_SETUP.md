# Vet record image OCR setup (Google Cloud Vision)

This project supports extracting text from vet record **photos** (JPG/PNG) via a Cloud Function:

- Function: `extractImageText`
- Code: `functions/imageExtraction.js`
- Export: `functions/index.js` (prod) and `functions/index_emulator.js` (emulator)

## Production setup (GCP/Firebase)

### 1) Enable the API
In the Google Cloud Console for your Firebase project:

- Enable **Cloud Vision API**.

### 2) Ensure the Cloud Functions runtime identity can call Vision
`functions/imageExtraction.js` uses Application Default Credentials (ADC) via the Cloud Functions service account.

Grant a Vision permission role to the service account used by Cloud Functions (commonly):

- Service account: `${PROJECT_ID}@appspot.gserviceaccount.com` (or the default Cloud Functions runtime service account for your project)
- Role suggestion: **Cloud Vision API User** (least-privilege)

If your org uses custom service accounts for Functions, grant the role to that identity instead.

### 3) Deploy Functions
From repo root:

- `cd functions && npm install`
- `firebase deploy --only functions`

After deploy, the endpoint will be available at:

- `https://us-central1-${PROJECT_ID}.cloudfunctions.net/extractImageText`

## Local emulator setup

### 1) Install dependencies
- `cd functions && npm install`

### 2) Provide credentials for Vision (local-only)
The Functions emulator runs on your machine, so it needs ADC.

Option A (recommended):
- `gcloud auth application-default login`

Option B:
- Create a service account JSON key
- Set: `export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/key.json"`

### 3) Start emulators
- `firebase emulators:start --only functions,firestore,auth,storage`

### 4) Point the Flutter app at emulators
Run the app with:

- `flutter run --dart-define=USE_FIREBASE_EMULATORS=true`

Defaults:

- Android emulator uses host `10.0.2.2`
- iOS simulator / macOS / web use `localhost`

If you’re running on a physical device, override the host with your machine’s LAN IP:

- `flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.50`

## Notes

- Camera capture is disabled on Flutter Web in the underwriting screen by default. Web users can still upload images via the file picker.
- OCR quality depends heavily on image sharpness and lighting. Vet letters photographed at an angle may yield partial text.
- PDF + image extraction Cloud Functions accept either a signed URL (`pdfUrl` / `imageUrl`) or a storage path (`gsPath`, like `gs://bucket/path`). The Flutter app sends both for reliability.

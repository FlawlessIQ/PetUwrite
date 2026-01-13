/**
 * Entrypoint selector for Cloud Functions.
 *
 * In the emulators, we load a minimal export surface to avoid pulling in
 * legacy/unused modules that can break local runs.
 *
 * In production deploys, we load the full index.
 */

// firebase-admin v13 compatibility: FieldValue is exported from
// "firebase-admin/firestore" rather than attached at admin.firestore.FieldValue.
// Many existing modules in this codebase still reference admin.firestore.FieldValue.
try {
  const admin = require("firebase-admin");
  const {FieldValue} = require("firebase-admin/firestore");
  if (admin?.firestore && !admin.firestore.FieldValue) {
    admin.firestore.FieldValue = FieldValue;
  }
} catch (_) {
  // Best-effort shim; if it fails the runtime will surface the real error.
}

function isEmulator() {
  return (
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.FUNCTIONS_EMULATOR === "1" ||
    !!process.env.FIREBASE_EMULATOR_HUB ||
    !!process.env.FUNCTIONS_EMULATOR_HOST ||
    !!process.env.FIRESTORE_EMULATOR_HOST ||
    !!process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    !!process.env.FIREBASE_STORAGE_EMULATOR_HOST
  );
}

module.exports = isEmulator()
  ? require("./index_emulator")
  : require("./index");

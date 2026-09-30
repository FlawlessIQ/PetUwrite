/**
 * The moment-email scheduler runs the app's engines from a generated bundle
 * (functions/generated/moments.js). If an engine changes and the bundle is not
 * rebuilt, the emails and the app would say different things — this fails.
 */
process.argv.push('--check')
await import('./build-moments.mjs')

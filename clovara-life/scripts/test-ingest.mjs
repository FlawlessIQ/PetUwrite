/**
 * Runs the lifeIngest emulator test (UB5) on its own ports.
 *
 * The default emulator ports (8080, 5001, 4400) are often held by another
 * project's emulators on the same machine, so this writes a throwaway copy of
 * firebase.json with spare ports, runs the test against it, and removes it.
 */
import { readFileSync, writeFileSync, rmSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const PORTS = { firestore: 8190, functions: 5111, hub: 4510, logging: 4610 }
const config = JSON.parse(readFileSync(resolve(root, 'firebase.json'), 'utf8'))
config.emulators = {
  firestore: { port: PORTS.firestore },
  functions: { port: PORTS.functions },
  hub: { port: PORTS.hub },
  logging: { port: PORTS.logging },
  ui: { enabled: false },
}
const tmp = resolve(root, 'firebase.ingest-test.json')
writeFileSync(tmp, JSON.stringify(config, null, 2))
const url = `http://127.0.0.1:${PORTS.functions}/pet-underwriter-ai/us-central1/lifeIngest`
try {
  const r = spawnSync(
    'npx',
    ['firebase', 'emulators:exec', '--config', tmp, '--only', 'functions,firestore', '--project', 'pet-underwriter-ai',
      `cd clovara-life/functions && INGEST_URL=${url} node --test ingest.emulator.test.js`],
    { cwd: root, stdio: 'inherit' },
  )
  process.exitCode = r.status ?? 1
} finally {
  rmSync(tmp, { force: true })
}

import { createHash } from "node:crypto";
import { access, cp, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const source = path.join(root, "build", "web");
const destination = path.join(root, "out", "app");
const indexPath = path.join(destination, "index.html");
const bootstrapPath = path.join(destination, "flutter_bootstrap.js");
const mainJsPath = path.join(source, "main.dart.js");

try {
  await access(path.join(source, "index.html"));
} catch {
  throw new Error(
    "Legacy Flutter web build not found at build/web. Run `flutter build web --release` before building the deployable site."
  );
}

await mkdir(destination, { recursive: true });
await cp(source, destination, { recursive: true, force: true });

const mainJs = await readFile(mainJsPath);
const appBuildId = createHash("sha256").update(mainJs).digest("hex").slice(0, 12);

const html = await readFile(indexPath, "utf8");
const appCacheResetScript = `<script>
  (function () {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.getRegistrations().then(function (registrations) {
      return Promise.all(registrations.map(function (registration) {
        return registration.scope.indexOf('/app/') !== -1 ? registration.unregister() : Promise.resolve(false);
      }));
    }).then(function () {
      if (!window.caches) return;
      return caches.keys().then(function (keys) {
        return Promise.all(keys.filter(function (key) {
          return key.indexOf('flutter') !== -1 || key.indexOf('clovara') !== -1;
        }).map(function (key) { return caches.delete(key); }));
      });
    });
  })();
</script>`;
const patched = html
  .replace('<base href="/">', '<base href="/app/">')
  .replace(
    '<script src="flutter_bootstrap.js" async></script>',
    `${appCacheResetScript}\n  <script src="flutter_bootstrap.js?v=${appBuildId}" async></script>`
  );
await writeFile(indexPath, patched);

const bootstrap = await readFile(bootstrapPath, "utf8");
const patchedBootstrap = bootstrap
  .replace('"mainJsPath":"main.dart.js"', `"mainJsPath":"main.dart.js?v=${appBuildId}"`)
  .replace(/serviceWorkerSettings:\s*\{\s*serviceWorkerVersion:\s*"[^"]+"\s*\/\*[\s\S]*?\*\/\s*\}/, "serviceWorkerSettings: null");
await writeFile(bootstrapPath, patchedBootstrap);

for (const route of ["sign-in", "app"]) {
  await writeFile(path.join(destination, `${route}.html`), patched);
  const routeDirectory = path.join(destination, route);
  await mkdir(routeDirectory, { recursive: true });
  await writeFile(path.join(routeDirectory, "index.html"), patched);
}

console.log(`Copied legacy authenticated app to out/app with /app/ base href and cache bust ${appBuildId}.`);

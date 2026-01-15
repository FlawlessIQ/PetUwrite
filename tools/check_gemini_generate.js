#!/usr/bin/env node

const fs = require('fs');

function loadEnvKey(path, name) {
  try {
    const text = fs.readFileSync(path, 'utf8');
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith('#') || !line.includes('=')) continue;
      const idx = line.indexOf('=');
      const k = line.slice(0, idx).trim();
      if (k !== name) continue;
      return line
        .slice(idx + 1)
        .trim()
        .replace(/^['"]|['"]$/g, '');
    }
  } catch {
    // ignore
  }
  return null;
}

async function main() {
  const key = loadEnvKey('.env', 'GEMINI_API_KEY');
  if (!key) {
    throw new Error('No GEMINI_API_KEY found in .env');
  }

  const url =
    'https://generativelanguage.googleapis.com/v1beta/' +
    'models/gemini-3-pro-preview:generateContent' +
    `?key=${encodeURIComponent(key)}`;

  const payload = {
    contents: [{ role: 'user', parts: [{ text: 'Reply with exactly: ping' }] }],
    generationConfig: { temperature: 0.2, maxOutputTokens: 256 },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const bodyText = await res.text();
  console.log('HTTP', res.status);

  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    body = null;
  }

  if (!res.ok) {
    const err = body?.error;
    console.log('status=', err?.status);
    const msg = String(err?.message || bodyText || '');
    console.log('message(first 240)=', msg.slice(0, 240));
    process.exit(1);
  }

  const cand = body?.candidates?.[0];
  const parts = cand?.content?.parts || [];
  const text = parts.map((p) => p?.text || '').join('').trim();
  console.log('text=', text);
  if (!text) {
    console.log('finishReason=', cand?.finishReason);
    console.log('hasParts=', Array.isArray(parts) ? parts.length : 0);
    const usage = body?.usageMetadata;
    if (usage) {
      console.log('usageMetadata=', JSON.stringify(usage));
    }
    console.log('raw(first 800)=', JSON.stringify(body).slice(0, 800));
    const safety = cand?.safetyRatings;
    if (safety) {
      console.log('safetyRatings=', JSON.stringify(safety).slice(0, 240));
    }
    const promptFeedback = body?.promptFeedback;
    if (promptFeedback) {
      console.log('promptFeedback=', JSON.stringify(promptFeedback).slice(0, 240));
    }
  }
}

main().catch((err) => {
  console.error(err?.message || String(err));
  process.exit(1);
});

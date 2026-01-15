#!/usr/bin/env python3
import json
import urllib.error
import urllib.request


def load_env_key(path: str, name: str) -> str | None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k.strip() != name:
                    continue
                return v.strip().strip('"').strip("'")
    except FileNotFoundError:
        return None


def main() -> None:
    key = load_env_key(".env", "GEMINI_API_KEY")
    if not key:
        raise SystemExit("No GEMINI_API_KEY found in .env")

    url = (
        "https://generativelanguage.googleapis.com/v1beta/"
        "models/gemini-3-pro-preview:generateContent"
        f"?key={key}"
    )
    payload = {
        "contents": [
            {"role": "user", "parts": [{"text": "Reply with exactly: ping"}]}
        ],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 16},
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", "replace")
            print("HTTP", resp.status)
            data = json.loads(body)
            parts = (
                (data.get("candidates") or [{}])[0]
                .get("content", {})
                .get("parts")
                or []
            )
            text = "".join([p.get("text", "") for p in parts]).strip()
            print("text=", text)
            return
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        print("HTTP", e.code)
        try:
            j = json.loads(body)
            err = j.get("error", {})
            print("status=", err.get("status"))
            msg = str(err.get("message") or "")
            print("message(first 240)=", msg[:240])
        except Exception:
            print("body(first 240)=", body[:240])


if __name__ == "__main__":
    main()

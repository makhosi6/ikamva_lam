#!/usr/bin/env bash
# Downloads Kokoro int8 ONNX + voices, writes voices.json for bundled TTS assets.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/assets/kokoro"
mkdir -p "$DEST"

ONNX_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx"
VOICES_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

ONNX_OUT="$DEST/kokoro-v1.0.int8.onnx"
BIN_OUT="$DEST/voices-v1.0.bin"
JSON_OUT="$DEST/voices.json"

if [[ ! -f "$ONNX_OUT" ]]; then
  echo "Downloading ONNX model…"
  curl -fL --retry 3 --retry-delay 2 -o "$ONNX_OUT" "$ONNX_URL"
else
  echo "Found $ONNX_OUT (skip download)"
fi

BUNDLE_OUT="$DEST/voices_bundle.json"
if [[ ! -f "$BUNDLE_OUT" ]]; then
  if [[ ! -f "$BIN_OUT" ]]; then
    echo "Downloading voices bin…"
    curl -fL --retry 3 --retry-delay 2 -o "$BIN_OUT" "$VOICES_URL"
  fi
  echo "Converting voices to JSON…"
  python3 "$ROOT/tool/voices_bin_to_json.py" "$BIN_OUT" "$JSON_OUT"
  echo "Writing lean voices bundle for the app (af_bella)…"
  export KOKORO_ROOT="$ROOT"
  python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["KOKORO_ROOT"])
full = root / "assets" / "kokoro" / "voices.json"
out = root / "assets" / "kokoro" / "voices_bundle.json"
data = json.loads(full.read_text())
if "af_bella" not in data:
    raise SystemExit("af_bella missing from voices.json")
out.write_text(json.dumps({"af_bella": data["af_bella"]}))
PY
else
  echo "Found $BUNDLE_OUT (skip voice download / conversion)"
fi
echo "Kokoro assets ready under $DEST"

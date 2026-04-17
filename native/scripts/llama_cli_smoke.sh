#!/usr/bin/env bash
# Smoke-test llama-cli + GGUF outside Flutter (TASKS §6.10).
# Same argv shape as learner_app/lib/llm/process_llm_engine.dart (runLlamaCliSync).
#
# Usage:
#   export IKAMVA_GGUF=/absolute/path/to/model.gguf
#   export IKAMVA_LLAMA_CLI=/path/to/llama-cli   # optional if native/build/bin/llama-cli exists
#   ./native/scripts/llama_cli_smoke.sh
#   ./native/scripts/llama_cli_smoke.sh --expect-json   # also require first balanced {...} to parse as JSON
#
# Optional env (defaults match app):
#   IKAMVA_MAX_NEW   max new tokens (default 120)
#   IKAMVA_CTX       context size (default 768)
#   IKAMVA_PROMPT    full prompt string (default: tiny JSON-only smoke)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_CLI="$ROOT/native/build/bin/llama-cli"

EXPECT_JSON=0
if [[ "${1:-}" == "--expect-json" ]]; then
  EXPECT_JSON=1
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '1,20p' "$0"
  exit 0
fi

CLI="${IKAMVA_LLAMA_CLI:-}"
if [[ -z "$CLI" && -x "$DEFAULT_CLI" ]]; then
  CLI="$DEFAULT_CLI"
fi
if [[ -z "$CLI" || ! -x "$CLI" ]]; then
  echo "ERROR: llama-cli not found or not executable: ${CLI:-<empty>}" >&2
  echo "  Build: chmod +x native/scripts/build_llama_cli.sh && ./native/scripts/build_llama_cli.sh" >&2
  echo "  Or set IKAMVA_LLAMA_CLI to the binary." >&2
  exit 2
fi

GGUF="${IKAMVA_GGUF:-}"
if [[ -z "$GGUF" || ! -f "$GGUF" ]]; then
  echo "ERROR: GGUF missing or not a file. Set IKAMVA_GGUF to an absolute path." >&2
  exit 2
fi

MAX_NEW="${IKAMVA_MAX_NEW:-120}"
CTX="${IKAMVA_CTX:-768}"
PROMPT="${IKAMVA_PROMPT:-OUTPUT JSON ONLY: {\"smoke\":true,\"n\":1}}"

echo "CLI:  $CLI"
echo "GGUF: $GGUF"
echo "Args: -n $MAX_NEW -c $CTX --no-display-prompt"
echo

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

start="$(date +%s)"
set +e
"$CLI" -m "$GGUF" -p "$PROMPT" -n "$MAX_NEW" -c "$CTX" --no-display-prompt >"$TMP_OUT" 2>&1
RC=$?
set -e
end="$(date +%s)"
EL=$((end - start))

echo "--- llama-cli combined output (exit $RC, ${EL}s wall) ---"
cat "$TMP_OUT"
echo "--- end ---"

if [[ "$RC" -ne 0 ]]; then
  exit "$RC"
fi

if [[ "$EXPECT_JSON" -eq 1 ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: --expect-json requested but python3 not found; skipping JSON check." >&2
    exit 0
  fi
  if ! python3 - "$TMP_OUT" <<'PY'
import json, sys
path = sys.argv[1]
raw = open(path, encoding="utf-8", errors="replace").read()
start = raw.find("{")
if start < 0:
    sys.exit(1)
depth = 0
for i in range(start, len(raw)):
    c = raw[i]
    if c == "{":
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0:
            json.loads(raw[start : i + 1])
            sys.exit(0)
sys.exit(1)
PY
  then
    echo "ERROR: --expect-json: no valid JSON object found in output (see LlmOutputFilters in app)." >&2
    exit 3
  fi
  echo "OK: first balanced {...} parses as JSON."
fi

exit 0

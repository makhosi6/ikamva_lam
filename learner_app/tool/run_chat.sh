#!/usr/bin/env bash
# Run the interactive native-LLM terminal chat (bin/native_llm_chat.dart).
#
# Usage:
#   ./tool/run_chat.sh              # GPU (default)
#   ./tool/run_chat.sh --gpu        # GPU explicitly
#   ./tool/run_chat.sh --cpu        # CPU only (three-tier XNNPack fallback)
#   ./tool/run_chat.sh -d DEVICE_ID # target a specific device
#
# Any extra args are forwarded to `flutter run` (e.g. --verbose, --release).
#
# From repo root:
#   learner_app/tool/run_chat.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$(dirname "$ROOT")/.env"
DEVICE="L7P7AIMZYLN7WCT8"   # default physical device
MODE="gpu"                    # default: GPU

# ── Parse args ──────────────────────────────────────────────────────────────
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gpu) MODE="gpu"; shift ;;
    --cpu) MODE="cpu"; shift ;;
    -d|--device) DEVICE="$2"; shift 2 ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ── Build dart-define list ───────────────────────────────────────────────────
DEFINES=()

# Load .env if present (HF token etc.)
if [[ -f "$ENV_FILE" ]]; then
  DEFINES+=("--dart-define-from-file=$ENV_FILE")
fi

if [[ "$MODE" == "gpu" ]]; then
  echo "==> chat mode: GPU  (PREFER_ANDROID_GPU + ESCALATE_CPU_FAIL_TO_GPU)"
  DEFINES+=(
    "--dart-define=IKAMVA_FORCE_CPU_BACKEND=0"
    "--dart-define=IKAMVA_ANDROID_GPU=1"
    "--dart-define=IKAMVA_PREFER_ANDROID_GPU=true"
    "--dart-define=IKAMVA_ESCALATE_LITERT_CPU_FAIL_TO_GPU=1"
  )
else
  echo "==> chat mode: CPU  (three-tier XNNPack fallback: 512→512 sync→256 Low RAM)"
  DEFINES+=(
    "--dart-define=IKAMVA_FORCE_CPU_BACKEND=1"
  )
fi

# ── Run ──────────────────────────────────────────────────────────────────────
cd "$ROOT"
echo "==> flutter run -d $DEVICE --target=bin/native_llm_chat.dart ${DEFINES[*]} ${EXTRA_ARGS[*]+"${EXTRA_ARGS[@]}"}"
exec flutter run \
  -d "$DEVICE" \
  --target=bin/native_llm_chat.dart \
  "${DEFINES[@]}" \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

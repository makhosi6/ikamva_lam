#!/usr/bin/env bash
# Build llama.cpp CLI for local dev (macOS/Linux). Android/iOS need their own
# toolchains — see native/README.md. TASKS §6.2
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REF_FILE="$ROOT/native/LLAMA_CPP_REF"
SRC="$ROOT/native/build/src/llama.cpp"
OUT_BIN="$ROOT/native/build/bin"
REF="$(tr -d '[:space:]' <"$REF_FILE")"

mkdir -p "$OUT_BIN"
if [[ ! -d "$SRC/.git" ]]; then
  git clone https://github.com/ggerganov/llama.cpp.git "$SRC"
fi

cd "$SRC"
git fetch --depth 1 origin "$REF"
git checkout FETCH_HEAD

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF

if cmake --build build --target llama-cli -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"; then
  cp -f build/bin/llama-cli "$OUT_BIN/llama-cli" || cp -f build/llama-cli "$OUT_BIN/llama-cli"
elif cmake --build build --target main -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"; then
  cp -f build/bin/main "$OUT_BIN/llama-cli" || cp -f build/main "$OUT_BIN/llama-cli"
else
  echo "Build failed: expected target llama-cli or main." >&2
  exit 1
fi

echo "Installed: $OUT_BIN/llama-cli (llama.cpp @ $REF)"

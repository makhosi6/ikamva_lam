#!/usr/bin/env bash
# Clear Flutter build artifacts, then run the app (same args as flutter run).
#
# Examples:
#   ./tool/clear_build_and_run.sh -d ios
#   ./tool/clear_build_and_run.sh -d android
#   ./tool/clear_build_and_run.sh -d chrome
# From repo root:
#   learner_app/tool/clear_build_and_run.sh -d ios
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"${ROOT}/tool/clear_flutter_build.sh"
echo "==> flutter run $*"
exec flutter run "$@"

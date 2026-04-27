#!/usr/bin/env bash
# Optional Flutter toolchain steps from on-device Gemma + Flutter guides that
# rely on experimental native-assets (e.g. some MediaPipe GenAI workflows).
#
# Ikamva Lam uses flutter_gemma on stable Flutter; you usually do NOT need this.
# Run only when a dependency’s docs explicitly require master + native-assets.
set -euo pipefail
flutter channel master
flutter upgrade
flutter config --enable-native-assets
echo "Done. Open a new terminal (or restart the IDE) so flutter picks up config changes."

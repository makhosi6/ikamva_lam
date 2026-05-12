#!/bin/bash
# Build Flutter app with CPU backend forced (avoids GPU buffer timeout crashes)
# Usage: ./build_with_cpu_backend.sh [ios|android]

set -e

DEVICE=${1:-android}

if [ "$DEVICE" != "ios" ] && [ "$DEVICE" != "android" ]; then
    echo "Usage: $0 [ios|android]"
    exit 1
fi

echo "🔧 Building for $DEVICE with CPU backend forced..."
echo "ℹ️  GPU initialization issues will be avoided."
echo ""

flutter clean
flutter pub get

if [ "$DEVICE" = "ios" ]; then
    flutter run -d ios \
        --dart-define=IKAMVA_FORCE_CPU_BACKEND=1 \
        --release
else
    flutter run -d android \
        --dart-define=IKAMVA_FORCE_CPU_BACKEND=1 \
        --release
fi

echo ""
echo "✅ Build complete! Using CPU backend to avoid GPU resource exhaustion."

#!/usr/bin/env bash
# Build a Play Store release AAB with R8 (Android) + Dart obfuscation.
set -euo pipefail

cd "$(dirname "$0")/.."

SYMBOLS_DIR="build/app/outputs/symbols"
MAPPING_FILE="build/app/outputs/mapping/release/mapping.txt"
AAB="build/app/outputs/bundle/release/app-release.aab"

echo "→ flutter pub get"
flutter pub get

echo "→ Building release app bundle (R8 + Dart obfuscate)..."
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR"

echo ""
echo "✅ Done."
echo "   AAB:     $AAB"
if [[ -f "$MAPPING_FILE" ]]; then
  echo "   R8 map:  $MAPPING_FILE  (upload to Play Console → App bundle explorer)"
fi
echo "   Dart symbols: $SYMBOLS_DIR  (Firebase Crashlytics)"
echo ""
echo "Upload AAB to Play Console Internal testing, then QA on a release install."

#!/bin/bash

echo "Running whisper_ggml tests..."

# Run unit tests
echo -e "\n=== Running unit tests ==="
flutter test test/whisper_audio_convert_test.dart

# Run integration tests (only on Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo -e "\n=== Running Linux integration tests ==="
  flutter test test/integration/whisper_audio_convert_integration_test.dart
else
  echo -e "\n=== Skipping Linux integration tests (not on Linux) ==="
fi

echo -e "\n=== Test run complete ==="
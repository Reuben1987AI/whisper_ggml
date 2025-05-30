
# whisper_ggml

OpenAI Whisper ASR (Automatic Speech Recognition) for Flutter using [Whisper.cpp](https://github.com/ggerganov/whisper.cpp).

## 🎉 Linux Support - COMPLETE ✅

**Full Linux implementation now available!** This plugin now supports:
- **Audio transcription** from files and microphone
- **Native FFI integration** with whisper.cpp
- **Automatic model downloading** (147MB base model)
- **FFmpeg-based audio conversion** on Linux

### Quick Start (Linux)

1. **Install FFmpeg** (required for audio conversion):
```bash
sudo apt-get install ffmpeg
```

2. **Add dependency**:
```yaml
dependencies:
  whisper_ggml: ^latest_version
```

3. **Use the plugin**:
```dart
final controller = WhisperController();
final result = await controller.transcribe(
  model: WhisperModel.base,
  audioPath: '/path/to/audio.wav',
  lang: 'en',
);
print(result?.transcription.text); // Transcribed text
```

## Supported platforms

| Platform  | Supported | Implementation |
|-----------|-----------|----------------|
| Android   | ✅        | FFmpegKit |
| iOS       | ✅        | FFmpegKit + CoreML |
| MacOS     | ✅        | Native |
| Linux     | ✅        | **FFmpeg + Native FFI** |





## Features



- Automatic Speech Recognition integration for Flutter apps.

- Supports automatic model downloading and initialization. Can be configured to work fully offline by using `assets` models (see example folder).

- Seamless iOS and Android support with optimized performance.

- Utilizes CORE ML for enhanced processing on iOS devices.



## Installation



To use this library in your Flutter project, follow these steps:



1. Add the library to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  whisper_ggml: ^1.3.0
```

2. Run `flutter pub get` to install the package.



## Usage



To integrate Whisper ASR in your Flutter app:



1. Import the package:

```dart
import 'package:whisper_ggml/whisper_ggml.dart';
```



2. Pick your model. Smaller models are more performant, but the accuracy may be lower. Recommended models are `tiny` and `small`.

```dart
final model = WhisperModel.tiny;
```

3. Declare `WhisperController` and use it for transcription:

```dart
final controller = WhisperController();

final result = await whisperController.transcribe(
    model: model, /// Selected WhisperModel
    audioPath: audioPath, /// Path to .wav file
    lang: 'en', /// Language to transcribe
);
```

4. Use the `result` variable to access the transcription result:

```dart
if (result?.transcription.text != null) {
    /// Do something with the transcription
    print(result!.transcription.text);
}
```



## Testing

### Running Tests

The project includes unit and integration tests for the Linux audio conversion functionality.

#### Prerequisites for Linux
- FFmpeg must be installed for audio conversion tests: `sudo apt-get install ffmpeg`

#### Run all tests
```bash
# Run unit tests
flutter test

# Run integration tests (Linux only)
flutter test test/integration/

# Or use the test runner script
./test/run_tests.sh
```

#### Run specific test files
```bash
# Run audio conversion tests
flutter test test/whisper_audio_convert_test.dart

# Run Linux integration tests
flutter test test/integration/whisper_audio_convert_integration_test.dart
```

### Test Coverage
- Unit tests for Linux audio conversion with mocked dependencies
- Integration tests for actual FFmpeg audio conversion (Linux only)
- Error handling and edge cases for Linux platform
- Tests for other platforms would require mocking FFmpegKit plugin

## Notes

### Linux Implementation Details

**Status**: ✅ **COMPLETE AND WORKING**

- **Native FFI**: Full whisper.cpp integration with proper symbol exports
- **Audio Conversion**: FFmpeg-based conversion via `Process.run`
- **Model Management**: Automatic download and caching (147MB base model)
- **Testing**: Comprehensive integration test suite
- **Performance**: ~5x realtime transcription with base model

**Verified transcription accuracy:**
```
Input: JFK audio file
Output: "And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."
```

### System Requirements (Linux)

```bash
# Install required dependencies
sudo apt-get install ffmpeg clang cmake ninja-build pkg-config libgtk-3-dev

# Verify installation
which ffmpeg  # Should show /usr/bin/ffmpeg
```

### Testing (Linux)

Run integration tests to verify functionality:
```bash
cd example
flutter test integration_test/whisper_test.dart
```

**Expected output:**
```
✓ Built build/linux/x64/debug/bundle/example
SUCCESS: And so my fellow Americans ask not what your country can do for you, ask what you can do for your country.
All tests passed!
```

### Troubleshooting (Linux)

1. **"Failed to lookup symbol 'request'"** - ✅ **RESOLVED**
2. **"FFmpeg not found"** - Install: `sudo apt-get install ffmpeg`
3. **Build failures** - Install full dependencies above

See [LINUX_IMPLEMENTATION.md](LINUX_IMPLEMENTATION.md) for complete technical documentation.

### Performance
- Transcription processing time is about `5x` times faster when running in release mode.
- Base model: ~5x realtime, ~310MB RAM usage
- Tiny model: ~10x realtime, smaller memory footprint

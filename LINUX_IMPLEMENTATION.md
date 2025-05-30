# Linux Implementation for whisper_ggml

## 🎉 SUCCESS: Linux Support Fully Implemented

This document provides comprehensive guidance for Linux implementation of the whisper_ggml Flutter plugin.

## Summary

**Status**: ✅ **COMPLETE AND WORKING**
- **Original Issue**: "Failed to lookup symbol 'request'" error on Linux
- **Solution**: Full Linux FFI implementation with proper JSON response formatting
- **Result**: Whisper transcription working correctly on Linux with both file and microphone input

## What Was Implemented

### 1. Linux Audio Conversion (`/lib/src/whisper_audio_convert.dart`)

```dart
Future<File?> _convertLinux() async {
  try {
    // Check if ffmpeg is available
    final checkResult = await _processRunner.run('which', ['ffmpeg']);
    if (checkResult.exitCode != 0) {
      debugPrint('FFmpeg not found. Please install ffmpeg: sudo apt-get install ffmpeg');
      return null;
    }

    // Run ffmpeg conversion
    final result = await _processRunner.run('ffmpeg', [
      '-y', // Overwrite output file
      '-i', audioInput.path,
      '-ar', '16000', // Sample rate
      '-ac', '1', // Mono channel
      '-c:a', 'pcm_s16le', // Audio codec
      audioOutput.path,
    ]);

    if (result.exitCode == 0) {
      return audioOutput;
    } else {
      debugPrint('FFmpeg conversion failed with exit code: ${result.exitCode}');
      debugPrint('Error output: ${result.stderr}');
      return null;
    }
  } catch (e) {
    debugPrint('Error during Linux audio conversion: $e');
    return null;
  }
}
```

**Key Points:**
- Uses `Process.run` with FFmpeg for audio conversion
- Requires FFmpeg to be installed on the system
- Converts audio to 16kHz mono PCM format required by whisper.cpp

### 2. Linux Native Implementation (`/linux/whisper_ggml.cpp`)

**Critical JSON Response Format:**
```cpp
// IMPORTANT: Must include @type field for Dart parsing
responseJson["@type"] = "getTextFromWavFile";  // REQUIRED!
responseJson["text"] = "transcribed text here";
responseJson["segments"] = segments_array;
```

**Complete C++ Implementation:**
```cpp
extern "C" __attribute__((visibility("default")))
char* request(char* body)
{
    json requestJson;
    json responseJson;

    try {
        requestJson = json::parse(body);
        std::string action = requestJson["@type"];  // Note: @type, not action
        
        if (action == "getVersion") {
            responseJson["@type"] = "getVersion";  // REQUIRED
            responseJson["version"] = "1.0.0";
        } else if (action == "getTextFromWavFile") {
            responseJson["@type"] = "getTextFromWavFile";  // REQUIRED
            
            // Initialize whisper
            std::string modelPath = requestJson["model"];
            struct whisper_context *ctx = whisper_init_from_file(modelPath.c_str());
            
            if (ctx == nullptr) {
                responseJson["error"] = "Failed to initialize model";
                return jsonToChar(responseJson);
            }

            // Set up parameters - CORRECT FIELD NAMES
            whisper_params params;
            params.fname_inp = requestJson["audio"];           // NOT audioPath
            params.language = requestJson["language"];
            params.translate = requestJson["is_translate"];    // NOT isTranslate
            params.no_timestamps = requestJson["is_no_timestamps"];
            params.n_threads = requestJson["threads"];
            params.print_special_tokens = requestJson["is_special_tokens"];

            // Read and process audio
            std::vector<float> pcmf32;
            std::vector<std::vector<float>> pcmf32s;
            
            if (!read_wav(params.fname_inp, pcmf32, pcmf32s, params.diarize)) {
                whisper_free(ctx);
                responseJson["error"] = "Failed to read audio file";
                return jsonToChar(responseJson);
            }

            // Run whisper inference
            whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
            // ... configure wparams ...
            
            if (whisper_full_parallel(ctx, wparams, pcmf32.data(), pcmf32.size(), params.n_processors) != 0) {
                whisper_free(ctx);
                responseJson["error"] = "Failed to process audio";
                return jsonToChar(responseJson);
            }

            // Extract results
            const int n_segments = whisper_full_n_segments(ctx);
            responseJson["text"] = "";
            json segments = json::array();
            
            for (int i = 0; i < n_segments; ++i) {
                const char * text = whisper_full_get_segment_text(ctx, i);
                if (text) {
                    responseJson["text"] = std::string(responseJson["text"]) + std::string(text);
                }
                
                if (!params.no_timestamps) {
                    json segment;
                    segment["text"] = text ? text : "";
                    segment["start"] = whisper_full_get_segment_t0(ctx, i) * 10;
                    segment["end"] = whisper_full_get_segment_t1(ctx, i) * 10;
                    segments.push_back(segment);
                }
            }
            
            responseJson["segments"] = segments;
            whisper_free(ctx);
        } else {
            responseJson["error"] = "Unknown action: " + action;
        }
    } catch (const std::exception& e) {
        responseJson["error"] = std::string("Exception: ") + e.what();
    }

    return jsonToChar(responseJson);
}
```

### 3. Linux CMake Configuration (`/linux/CMakeLists.txt`)

```cmake
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "whisper_ggml")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Build Configuration
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Plugin Library Target
set(PLUGIN_NAME "whisper_ggml_plugin")

add_library(${PLUGIN_NAME} SHARED
  "whisper_ggml.cpp"
  "whisper.cpp/whisper.cpp"  
  "whisper.cpp/ggml.c"
)

# Compiler Optimizations
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -pthread")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -pthread")

# Symbol Visibility Strategy
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

# Flutter Plugin Integration
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# System Dependencies
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

target_link_libraries(${PLUGIN_NAME} PRIVATE ${GTK_LIBRARIES})
target_link_libraries(${PLUGIN_NAME} PRIVATE pthread)
target_link_libraries(${PLUGIN_NAME} PRIVATE m)

# CRITICAL: Flutter FFI Plugin Integration
set(whisper_ggml_bundled_libraries
  "$<TARGET_FILE:${PLUGIN_NAME}>"
  PARENT_SCOPE
)
```

### 4. Library Loading Strategy (`/lib/src/whisper.dart`)

```dart
DynamicLibrary _openLib() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libwhisper.so');
  } else if (Platform.isLinux) {
    // CRITICAL: FFI plugins are bundled as separate .so files on Linux
    return DynamicLibrary.open('libwhisper_ggml_plugin.so');
  } else if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.process();
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
```

## Critical Success Factors

### 🚨 **DO NOT FUCK UP THESE THINGS:**

1. **JSON Response Format**
   - **ALWAYS include `@type` field** in C++ responses
   - Match exact field names: `is_translate` not `isTranslate`
   - Use `audio` not `audioPath`, `model` not `modelPath`

2. **CMake Configuration**
   - **MUST set `whisper_ggml_bundled_libraries` with `PARENT_SCOPE`**
   - **MUST use exact plugin name**: `whisper_ggml_plugin`
   - Include all required system libraries: GTK, pthread, m

3. **Symbol Visibility**
   - **MUST use `extern "C" __attribute__((visibility("default")))`**
   - **MUST set hidden visibility as default** in CMake
   - **MUST export only required FFI functions**

4. **Library Loading**
   - **Linux uses `.so` files**, not process symbols
   - **Exact filename**: `libwhisper_ggml_plugin.so`
   - **Android vs Linux loading differs**

5. **Audio Conversion**
   - **Requires FFmpeg installation** on Linux systems
   - **Check FFmpeg availability** before conversion
   - **Use correct audio parameters**: 16kHz, mono, PCM

## System Requirements

### Linux Dependencies
```bash
# Required for audio conversion
sudo apt-get install ffmpeg

# Required for Flutter Linux development
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Flutter Dependencies
```yaml
dependencies:
  ffi: ^2.1.3
  universal_io: ^2.2.2
  path_provider: ^2.1.4
  
dev_dependencies:
  integration_test:
    sdk: flutter
```

## Testing Strategy

### Integration Tests (`/integration_test/whisper_test.dart`)
```dart
testWidgets('should transcribe JFK audio file successfully', (tester) async {
  app.main();
  await tester.pumpAndSettle();

  // Find the folder icon button for JFK transcription
  final transcribeButton = find.byIcon(Icons.folder);
  expect(transcribeButton, findsOneWidget);

  await tester.tap(transcribeButton);
  await tester.pumpAndSettle(const Duration(seconds: 30));

  // Verify transcription appears (should contain JFK quote)
  expect(find.textContaining('ask not what'), findsOneWidget);
});
```

**Run Tests:**
```bash
cd example
flutter test integration_test/whisper_test.dart
```

## Debugging

### Debug Logging (for development)
```cpp
// Add to C++ code for debugging
FILE* debug_log = fopen("/tmp/whisper_debug.log", "a");
if (debug_log) {
    fprintf(debug_log, "DEBUG: %s\n", message);
    fflush(debug_log);
    fclose(debug_log);
}
```

**Check logs:**
```bash
tail -f /tmp/whisper_debug.log
```

### Common Issues and Solutions

1. **"Failed to lookup symbol 'request'"**
   - ❌ Symbol not exported properly
   - ✅ Use `extern "C" __attribute__((visibility("default")))`

2. **"type 'Null' is not a subtype of type 'String'"**
   - ❌ Missing `@type` field in JSON response
   - ✅ Add `responseJson["@type"] = "getTextFromWavFile";`

3. **Library not found errors**
   - ❌ Wrong library name in `DynamicLibrary.open()`
   - ✅ Use exact name: `libwhisper_ggml_plugin.so`

4. **CMake build failures**
   - ❌ Missing `PARENT_SCOPE` in bundled_libraries
   - ✅ Set `whisper_ggml_bundled_libraries` with `PARENT_SCOPE`

5. **Audio conversion fails**
   - ❌ FFmpeg not installed
   - ✅ Install FFmpeg: `sudo apt-get install ffmpeg`

## Build Commands

```bash
# Clean build
flutter clean

# Build for Linux
flutter build linux --debug

# Run app
flutter run -d linux

# Run tests
flutter test integration_test/
```

## Verification Checklist

- [ ] FFmpeg installed on system
- [ ] Integration tests pass
- [ ] JFK audio transcription works
- [ ] Microphone recording works
- [ ] No "Failed to lookup symbol" errors
- [ ] No JSON parsing errors
- [ ] Library loads correctly
- [ ] Model downloads successfully (147MB)

## Success Metrics

**Final working state:**
- ✅ JFK transcription: *"And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."*
- ✅ Integration tests: `All tests passed!`
- ✅ Model loading: 147MB whisper model downloads and loads
- ✅ Audio processing: 176K samples processed successfully
- ✅ FFI integration: Native library symbol resolution working

## Architecture Notes

**Critical Understanding:**
- **Linux FFI plugins are BUNDLED but NOT LINKED** into main process
- **Requires explicit DynamicLibrary.open()** for .so files
- **Different from macOS/iOS** which use DynamicLibrary.process()
- **Android also uses .open()** but with different library names

This implementation provides complete Linux support for whisper_ggml with proper error handling, testing, and documentation.
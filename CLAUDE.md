# CLAUDE.md - Development Directives

## Core Programming Principles

### 1. **VERIFY BEFORE SUBMIT** ⚠️
**NEVER submit code without compilation verification**
- Every code change MUST be compiled/tested before declaring complete
- Use `flutter build linux --debug` for Flutter projects
- Use `cmake --build .` for CMake projects
- No exceptions - syntax errors are unacceptable

### 2. **PAIRED CONSTRUCT INTEGRITY**
**When modifying paired constructs, verify both sides**
- Braces: `{` must have matching `}`
- Preprocessor: `#ifdef` must have `#endif`
- Comments: `/*` must have `*/`
- Quotes: `"` must be properly closed
- **Rule**: Count opening/closing constructs before submitting

### 3. **SYSTEMATIC ARCHITECTURE ANALYSIS**
**Understand the system before making changes**
- Read existing CMakeLists.txt completely before modifying
- Understand Flutter's plugin architecture (FFI vs method channels)
- Check generated_plugins.cmake to understand integration
- **Never guess** - research first, implement second

### 4. **BUILD SYSTEM RESPECT**
**Work WITH the build system, not against it**
- Flutter expects specific variable names (e.g., `${plugin}_bundled_libraries`)
- CMake uses PARENT_SCOPE for cross-directory variable sharing
- Understand library loading: DynamicLibrary.process() vs .open()
- **Rule**: Follow conventions, don't fight them

### 5. **SYMBOL VISIBILITY DISCIPLINE**
**Be explicit about what's exported**
- Default to hidden visibility: `CXX_VISIBILITY_PRESET hidden`
- Export only required symbols: `__attribute__((visibility("default")))`
- Document every exported symbol with justification
- **Rule**: Minimize attack surface through selective exports

### 6. **PLATFORM-SPECIFIC LOGIC**
**Understand platform differences deeply**
- Android: Manual .so loading required
- Linux: FFI plugins are BUNDLED but NOT LINKED - require explicit .so loading
- macOS/iOS: Symbols statically linked
- **CRITICAL**: Never assume DynamicLibrary.process() works for FFI plugins
- **Rule**: Verify library loading behavior through actual testing

### 7. **ERROR CONTEXT PRESERVATION**
**When fixing errors, understand root cause**
- Don't just fix symptoms - understand why the error occurred
- Document the failure mode for future reference
- Implement checks to prevent recurrence
- **Rule**: Learn from every failure

### 8. **DEPENDENCY CHAIN ANALYSIS**
**Understand the full dependency stack**
- CMake → Flutter → Dart FFI → Native library
- Each layer has specific requirements and conventions
- Breaking one link breaks the entire chain
- **Rule**: Trace dependencies end-to-end

### 9. **DOCUMENTATION AS CODE**
**Document architectural decisions inline**
- Every CMakeLists.txt should explain why, not just what
- Complex configurations need justification comments
- Include trade-offs and alternatives considered
- **Rule**: Code should tell a story of why it exists

### 10. **INCREMENTAL VERIFICATION**
**Test each change in isolation**
- Make one logical change at a time
- Verify it works before moving to the next change
- Don't bundle multiple unrelated changes
- **Rule**: Bisect-able history requires atomic commits

## Flutter-Specific Directives

### Linux Plugin Development
- Always check `generated_plugins.cmake` for plugin integration
- Use `flutter pub deps` to verify plugin detection
- FFI plugins: set `${plugin_name}_bundled_libraries` with PARENT_SCOPE
- Native plugins: implement proper registrar functions
- **CRITICAL**: FFI plugins on Linux require explicit DynamicLibrary.open(), NOT process()

### FFI Plugin Library Loading Rules
- **Android**: `DynamicLibrary.open('libname.so')` 
- **Linux**: `DynamicLibrary.open('libplugin_name_plugin.so')` 
- **macOS/iOS**: `DynamicLibrary.process()`
- **Rule**: Test library loading on each platform - assumptions kill

### CMake Best Practices
- Use `find_package(PkgConfig REQUIRED)` for system dependencies
- Link pthread explicitly for multi-threaded code
- Set CMAKE_POSITION_INDEPENDENT_CODE for shared libraries
- Use `$<TARGET_FILE:target>` for library paths

### Symbol Export Strategy
```cpp
// Correct approach for FFI exports
extern "C" __attribute__((visibility("default")))
return_type function_name(parameters);
```

## Error Prevention Checklist

Before submitting ANY code change:

- [ ] Code compiles successfully
- [ ] All braces/brackets/parentheses properly matched
- [ ] No orphaned preprocessor directives
- [ ] Variable names match expected conventions
- [ ] Platform-specific logic properly isolated
- [ ] Dependencies correctly declared
- [ ] Symbols exported as intended
- [ ] Documentation updated for changes
- [ ] Change can be explained in one sentence

## Build Commands Reference

### Flutter Projects
```bash
# Clean build verification
flutter clean
flutter pub get
flutter build linux --debug

# Verify plugin detection
flutter pub deps | grep plugin_name

# Check generated files
cat linux/flutter/generated_plugins.cmake
```

### CMake Verification
```bash
# Check symbol exports
nm -D path/to/library.so | grep function_name

# Verify library dependencies
ldd path/to/library.so
```

## Failure Recovery Protocol

When a build fails:

1. **STOP** - Don't make more changes
2. **READ** the complete error message
3. **UNDERSTAND** the root cause
4. **FIX** the minimum necessary change
5. **VERIFY** the fix compiles
6. **DOCUMENT** what went wrong

## Linux Implementation - COMPLETE ✅

**Status**: Linux support for whisper_ggml is **FULLY IMPLEMENTED AND WORKING**

### What Works:
- ✅ Linux FFI library loading (`libwhisper_ggml_plugin.so`)
- ✅ Whisper model downloading and loading (147MB)
- ✅ Linux audio conversion using FFmpeg Process.run
- ✅ Native whisper transcription engine
- ✅ JSON response format matching Dart expectations
- ✅ Integration tests passing
- ✅ JFK audio transcription: *"And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."*

### Key Fixes Applied:
1. **JSON Response Format**: Added required `@type` field to C++ responses
2. **Field Name Mapping**: Corrected `audio` vs `audioPath`, `is_translate` vs `isTranslate`
3. **Library Loading**: `DynamicLibrary.open('libwhisper_ggml_plugin.so')` for Linux
4. **CMake Configuration**: Proper `whisper_ggml_bundled_libraries` with `PARENT_SCOPE`
5. **Symbol Export**: `extern "C" __attribute__((visibility("default")))` for request function

### Testing Commands

```bash
# Always run these before submitting:
cd /home/maoholden/Documents/vibe-coding/ext-repos/whisper_ggml/example

# 1. Verify compilation
flutter build linux --debug

# 2. Run integration tests  
flutter test integration_test/whisper_test.dart

# 3. Expected results:
# - "All tests passed!"
# - JFK transcription working
# - No "Failed to lookup symbol" errors
```

### Integration Test Results (Final)

```
✓ Built build/linux/x64/debug/bundle/example
00:07 +0: Whisper GGML Linux Integration Tests should transcribe JFK audio file successfully
Transcription completed, result: Instance of 'TranscribeResult'
SUCCESS: And so my fellow Americans ask not what your country can do for you, ask what you can do for your country.
=== Text widgets found: 2 ===
Text widget 0: " And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."
SUCCESS: Text changed from default
Has result: true
01:23 +2: All tests passed!
```

**Result**: Linux implementation is complete and working correctly.

## Success Metrics

- Zero compilation errors on first attempt
- Zero orphaned constructs (braces, ifdefs, etc.)
- Zero symbol resolution failures
- Zero library loading errors
- 100% architectural decision documentation

**Remember: As a senior architect, every line of code reflects on system design competence. There are no "small" mistakes in production systems.**
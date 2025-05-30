# Flutter Linux Plugin Build System Analysis

## Architecture Overview

### Flutter Plugin Loading Mechanism
Flutter on Linux uses a plugin system where:
1. **Plugin Registration**: Plugins register themselves in `flutter/generated_plugin_registrant.cc`
2. **Library Loading**: Flutter loads plugin libraries as shared objects (.so)
3. **Symbol Resolution**: Plugin methods are called through a standardized interface

### Current Implementation Issues

#### Problem 1: Symbol Export Confusion
**Issue**: Mixed visibility settings with attribute overrides
```cmake
# WRONG: Setting visibility to hidden then trying to override
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)
# Then adding: __attribute__((visibility("default")))
```

**Root Cause**: Fundamental misunderstanding of how Flutter plugins export symbols

#### Problem 2: Library Loading Strategy
**Issue**: Trying to manually load the plugin library in Dart FFI
```dart
// WRONG: Manual library loading bypasses Flutter's plugin system
DynamicLibrary.open('libwhisper_ggml_plugin.so')
```

**Root Cause**: Flutter plugins should integrate with the plugin registration system, not bypass it

#### Problem 3: CMake Configuration
**Issue**: Incorrect export flags and bundling
```cmake
# WRONG: export-dynamic is for executables, not shared libraries
set_property(TARGET ${PLUGIN_NAME} PROPERTY LINK_FLAGS "-Wl,--export-dynamic")
```

## Correct Architecture

### 1. Plugin Registration Approach
Flutter Linux plugins should:
- Register through the plugin system
- Export standardized entry points
- Use Flutter's method channel or FFI integration

### 2. Symbol Export Strategy
For FFI-based plugins:
```cpp
// Correct approach: Export specific symbols with default visibility
extern "C" __attribute__((visibility("default"))) {
    char* request(char* body);
}
```

### 3. CMake Best Practices
```cmake
# Build shared library with appropriate settings
add_library(${PLUGIN_NAME} SHARED source_files...)

# Set visibility: hide by default, export explicitly
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

# Let Flutter handle bundling
set(${PROJECT_NAME}_bundled_libraries
  $<TARGET_FILE:${PLUGIN_NAME}>
  PARENT_SCOPE
)
```

## Root Cause Analysis

### The Real Issue
After examining `generated_plugins.cmake`, the issue is clear:

1. **Plugin Registration**: `whisper_ggml` IS properly registered as an FFI plugin
2. **Build Integration**: Flutter DOES build FFI plugins automatically  
3. **Variable Naming**: Our CMakeLists.txt uses wrong variable name

```cmake
# Current (WRONG):
set(whisper_ggml_bundled_libraries ...)

# Flutter expects this pattern for FFI plugins:
set(whisper_ggml_bundled_libraries ... PARENT_SCOPE)
```

### Flutter FFI Plugin Architecture
```
1. Flutter scans pubspec.yaml for FFI plugins
2. Adds plugin to FLUTTER_FFI_PLUGIN_LIST
3. Calls add_subdirectory for plugin's linux/ folder
4. Expects plugin to set ${plugin_name}_bundled_libraries
5. Bundles those libraries automatically
```

## Correct Implementation

### 1. Proper CMakeLists.txt Structure
```cmake
# Build the plugin library
add_library(${PLUGIN_NAME} SHARED sources...)

# Export specific symbols only
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Set bundled libraries for Flutter to include
set(whisper_ggml_bundled_libraries
  "$<TARGET_FILE:${PLUGIN_NAME}>"
  PARENT_SCOPE
)
```

### 2. Symbol Export Strategy  
```cpp
// Use extern "C" with explicit export
extern "C" __attribute__((visibility("default"))) 
char* request(char* body);
```

### 3. Dart FFI Integration
```dart
// Let Flutter handle library loading via process
DynamicLibrary _openLib() {
  return DynamicLibrary.process(); // Works for FFI plugins
}
```

## The Fix
1. Correct variable name in CMakeLists.txt
2. Remove manual library loading code
3. Use DynamicLibrary.process() for FFI plugins
4. Ensure proper symbol export
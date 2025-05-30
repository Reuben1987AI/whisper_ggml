# Flutter Linux Plugin Build Configuration
# 
# This file builds whisper_ggml as an FFI plugin for Flutter Linux applications.
# 
# Architecture Decision: FFI Plugin Approach
# - Reason: Direct C++ integration with minimal Flutter overhead
# - Trade-off: More complex symbol management vs method channels
# - Justification: Performance-critical audio processing requires direct FFI access

cmake_minimum_required(VERSION 3.10)

# Project Configuration
# Using "whisper_ggml" to match Flutter's plugin naming convention
set(PROJECT_NAME "whisper_ggml")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Build Configuration
# Setting C++11 for compatibility with whisper.cpp requirements
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Plugin Library Target
# Flutter expects FFI plugins to build a shared library
set(PLUGIN_NAME "whisper_ggml_plugin")

add_library(${PLUGIN_NAME} SHARED
  "whisper_ggml.cpp"
  "whisper.cpp/whisper.cpp"  
  "whisper.cpp/ggml.c"
)

# Compiler Optimizations
# Reason: Audio processing is CPU-intensive, O3 optimization is critical
# Trade-off: Longer build time vs runtime performance
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -pthread")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -pthread")

# Symbol Visibility Strategy
# Approach: Hide symbols by default, export only required FFI functions
# Reason: Reduces symbol conflicts and improves library loading performance
# Trade-off: More explicit export annotations required
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

# Flutter Plugin Integration
# Required definition for Flutter plugin compatibility
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# System Dependencies
# GTK3: Required by Flutter Linux for UI integration
# pthread: Required by whisper.cpp for multi-threading
# m: Math library for whisper.cpp mathematical operations
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

target_link_libraries(${PLUGIN_NAME} PRIVATE ${GTK_LIBRARIES})
target_link_libraries(${PLUGIN_NAME} PRIVATE pthread)
target_link_libraries(${PLUGIN_NAME} PRIVATE m)

# Flutter FFI Plugin Integration
# Critical: Variable name MUST match plugin name for Flutter's automatic discovery
# Flutter scans for ${plugin_name}_bundled_libraries in generated_plugins.cmake
# PARENT_SCOPE ensures the variable is available to Flutter's build system
set(whisper_ggml_bundled_libraries
  "$<TARGET_FILE:${PLUGIN_NAME}>"
  PARENT_SCOPE
)
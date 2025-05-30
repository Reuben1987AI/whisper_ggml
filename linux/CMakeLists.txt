# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "whisper_ggml")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "whisper_ggml_plugin")

# Define the plugin library target
add_library(${PLUGIN_NAME} SHARED
  "whisper_ggml.cpp"
  "whisper.cpp/whisper.cpp"
  "whisper.cpp/ggml.c"
)

# Set optimization flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -pthread")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -pthread")

# Apply standard settings
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

# Ensure the request function is exported
set_property(TARGET ${PLUGIN_NAME} PROPERTY LINK_FLAGS "-Wl,--export-dynamic")

# Add definitions
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Include directories
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# System libraries
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

target_link_libraries(${PLUGIN_NAME} PRIVATE ${GTK_LIBRARIES})
target_link_libraries(${PLUGIN_NAME} PRIVATE pthread)
target_link_libraries(${PLUGIN_NAME} PRIVATE m)

# List of absolute paths to libraries that should be bundled with the plugin
# This ensures the plugin library is available at runtime
set(whisper_ggml_bundled_libraries
  "$<TARGET_FILE:${PLUGIN_NAME}>"
  PARENT_SCOPE
)
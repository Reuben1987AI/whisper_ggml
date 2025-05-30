# Linux Build Instructions

## Prerequisites

1. **CMake** (3.10 or later)
   ```bash
   sudo apt-get install cmake
   ```

2. **GTK3 Development Libraries**
   ```bash
   sudo apt-get install libgtk-3-dev
   ```

3. **Build Tools**
   ```bash
   sudo apt-get install build-essential
   ```

4. **FFmpeg** (for audio conversion)
   ```bash
   sudo apt-get install ffmpeg
   ```

## Building

The plugin will be automatically built when you run your Flutter app on Linux:

```bash
flutter run -d linux
```

Or build manually:

```bash
cd linux
mkdir -p build
cd build
cmake ..
make
```

## Troubleshooting

### Symbol lookup errors

If you get "Failed to lookup symbol" errors, ensure:
1. The plugin is properly built
2. Check the library is in the correct location:
   ```bash
   find build -name "*.so"
   ```

### Missing dependencies

If cmake fails, install missing dependencies:
```bash
sudo apt-get update
sudo apt-get install pkg-config
```

## Architecture

The Linux implementation provides a native C++ library that:
1. Exports the `request` function for FFI
2. Links against whisper.cpp for speech recognition
3. Uses the same JSON protocol as Android/iOS implementations
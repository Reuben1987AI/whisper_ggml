@TestOn('linux')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart' as uio;
import 'package:whisper_ggml/src/whisper_audio_convert.dart';

import '../test_utils.dart';

void main() {
  late Directory tempDir;
  late uio.File inputFile;
  late uio.File outputFile;

  setUpAll(() async {
    // Check if ffmpeg is available
    final result = await Process.run('which', ['ffmpeg']);
    if (result.exitCode != 0) {
      throw StateError('''
╔══════════════════════════════════════════════════════════════════════════════╗
║                              FFmpeg NOT FOUND!                               ║
║                                                                              ║
║  Integration tests require FFmpeg to be installed on your system.            ║
║                                                                              ║
║  To install FFmpeg:                                                          ║
║  • Ubuntu/Debian:  sudo apt-get install ffmpeg                              ║
║  • Fedora:         sudo dnf install ffmpeg                                  ║
║  • Arch:           sudo pacman -S ffmpeg                                    ║
║  • macOS:          brew install ffmpeg                                      ║
║                                                                              ║
║  Please install FFmpeg and run the tests again.                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
''');
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whisper_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WhisperAudioConvert Integration Tests', () {
    test('should convert WAV to 16kHz mono WAV with correct format', () async {
      // Arrange - create a 44.1kHz stereo WAV
      final inputPath = path.join(tempDir.path, 'test_input_44khz.wav');
      final outputPath = path.join(tempDir.path, 'test_output.wav');
      
      // Create a test WAV with different sample rate to test conversion
      final file = uio.File(inputPath);
      final header = TestUtils.createWavHeader(
        sampleRate: 44100, 
        channels: 2,
        dataSize: 4410, // 0.05 second at 44.1kHz stereo
      );
      final data = Uint8List(4410);
      await file.writeAsBytes([...header, ...data]);
      
      inputFile = file;
      outputFile = uio.File(outputPath);
      
      final converter = WhisperAudioConvert(
        audioInput: inputFile,
        audioOutput: outputFile,
      );

      // Act
      final result = await converter.convert();

      // Assert
      expect(result, isNotNull);
      expect(await outputFile.exists(), isTrue);
      
      // Verify WAV format using ffprobe
      final probeResult = await Process.run('ffprobe', [
        '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=sample_rate,channels,codec_name',
        '-of', 'csv=p=0',
        outputPath,
      ]);
      
      if (probeResult.exitCode == 0) {
        final info = probeResult.stdout.toString().trim();
        expect(info, contains('pcm_s16le')); // Codec
        expect(info, contains('16000')); // Sample rate
        expect(info, contains('1')); // Channels (mono)
      }
    });

    test('should handle non-existent input file gracefully', () async {
      // Arrange
      final nonExistentFile = uio.File(path.join(tempDir.path, 'non_existent.mp3'));
      final outputPath = path.join(tempDir.path, 'output.wav');
      outputFile = uio.File(outputPath);
      
      final converter = WhisperAudioConvert(
        audioInput: nonExistentFile,
        audioOutput: outputFile,
      );

      // Act
      final result = await converter.convert();

      // Assert
      expect(result, isNull);
      expect(await outputFile.exists(), isFalse);
    });

    test('should convert actual WAV file maintaining quality', () async {
      // Arrange
      final inputPath = path.join(tempDir.path, 'test_input.wav');
      final outputPath = path.join(tempDir.path, 'test_output.wav');
      
      inputFile = await TestUtils.createTestWavFile(inputPath);
      outputFile = uio.File(outputPath);
      
      final converter = WhisperAudioConvert(
        audioInput: inputFile,
        audioOutput: outputFile,
      );

      // Act
      final result = await converter.convert();

      // Assert
      expect(result, isNotNull);
      expect(await outputFile.exists(), isTrue);
      
      // Check file size is reasonable (should be similar for WAV to WAV)
      final inputSize = await inputFile.length();
      final outputSize = await outputFile.length();
      expect(outputSize, greaterThan(0));
      expect(outputSize, lessThan(inputSize * 2)); // Should not be drastically larger
    });

    test('should overwrite existing output file', () async {
      // Arrange
      final inputPath = path.join(tempDir.path, 'test_input.wav');
      final outputPath = path.join(tempDir.path, 'test_output.wav');
      
      inputFile = await TestUtils.createTestWavFile(inputPath);
      outputFile = uio.File(outputPath);
      
      // Create existing output file with different content
      await outputFile.writeAsBytes([1, 2, 3, 4, 5]);
      final originalSize = await outputFile.length();
      
      final converter = WhisperAudioConvert(
        audioInput: inputFile,
        audioOutput: outputFile,
      );

      // Act
      final result = await converter.convert();

      // Assert
      expect(result, isNotNull);
      expect(await outputFile.exists(), isTrue);
      
      final newSize = await outputFile.length();
      expect(newSize, isNot(equals(originalSize))); // File was overwritten
      expect(newSize, greaterThan(44)); // Should have at least WAV header
    });
  });
}
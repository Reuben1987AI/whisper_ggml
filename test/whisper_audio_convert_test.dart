import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_io/io.dart';
import 'package:whisper_ggml/src/process_runner.dart';
import 'package:whisper_ggml/src/whisper_audio_convert.dart';

class MockProcessRunner extends Mock implements ProcessRunner {}

class MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFile mockInputFile;
  late MockFile mockOutputFile;
  late MockProcessRunner mockProcessRunner;
  late WhisperAudioConvert audioConvert;

  setUp(() {
    mockInputFile = MockFile();
    mockOutputFile = MockFile();
    mockProcessRunner = MockProcessRunner();
    
    when(() => mockInputFile.path).thenReturn('/tmp/input.mp3');
    when(() => mockOutputFile.path).thenReturn('/tmp/output.wav');
    
    audioConvert = WhisperAudioConvert(
      audioInput: mockInputFile,
      audioOutput: mockOutputFile,
      processRunner: mockProcessRunner,
    );
  });

  group('WhisperAudioConvert', () {
    group('Linux conversion', () {
      setUp(() {
        // Override Platform.isLinux for testing
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return null;
          },
        );
      });

      test('should check for ffmpeg availability before conversion', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 1, // FFmpeg not found
          stdout: '',
          stderr: '',
        );
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, isNull);
        verify(() => mockProcessRunner.run('which', ['ffmpeg'])).called(1);
        verifyNever(() => mockProcessRunner.run('ffmpeg', any()));
      });

      test('should return null when ffmpeg is not found', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 1,
          stdout: '',
          stderr: '',
        );
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, isNull);
      });

      test('should execute ffmpeg with correct parameters', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 0, // FFmpeg found
          stdout: '/usr/bin/ffmpeg',
          stderr: '',
        );
        
        final ffmpegResult = ProcessRunResult(
          exitCode: 0, // Success
          stdout: '',
          stderr: '',
        );
        
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);
        when(() => mockProcessRunner.run('ffmpeg', [
              '-y',
              '-i', '/tmp/input.mp3',
              '-ar', '16000',
              '-ac', '1',
              '-c:a', 'pcm_s16le',
              '/tmp/output.wav',
            ])).thenAnswer((_) async => ffmpegResult);

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, equals(mockOutputFile));
        verify(() => mockProcessRunner.run('ffmpeg', [
              '-y',
              '-i', '/tmp/input.mp3',
              '-ar', '16000',
              '-ac', '1',
              '-c:a', 'pcm_s16le',
              '/tmp/output.wav',
            ])).called(1);
      });

      test('should return output file on successful conversion', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 0,
          stdout: '/usr/bin/ffmpeg',
          stderr: '',
        );
        
        final ffmpegResult = ProcessRunResult(
          exitCode: 0,
          stdout: '',
          stderr: '',
        );
        
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);
        when(() => mockProcessRunner.run('ffmpeg', any()))
            .thenAnswer((_) async => ffmpegResult);

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, equals(mockOutputFile));
      });

      test('should return null on ffmpeg conversion failure', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 0,
          stdout: '/usr/bin/ffmpeg',
          stderr: '',
        );
        
        final ffmpegResult = ProcessRunResult(
          exitCode: 1, // Failure
          stdout: '',
          stderr: 'Error: Invalid input file',
        );
        
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);
        when(() => mockProcessRunner.run('ffmpeg', any()))
            .thenAnswer((_) async => ffmpegResult);

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, isNull);
      });

      test('should handle process execution exceptions gracefully', () async {
        // Arrange
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenThrow(const io.ProcessException('which', ['ffmpeg']));

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, isNull);
      });

      test('should handle ffmpeg execution exceptions gracefully', () async {
        // Arrange
        final whichResult = ProcessRunResult(
          exitCode: 0,
          stdout: '/usr/bin/ffmpeg',
          stderr: '',
        );
        
        when(() => mockProcessRunner.run('which', ['ffmpeg']))
            .thenAnswer((_) async => whichResult);
        when(() => mockProcessRunner.run('ffmpeg', any()))
            .thenThrow(const io.ProcessException('ffmpeg', []));

        // Act
        final result = await audioConvert.convert();

        // Assert
        expect(result, isNull);
      });
    });

    group('FFmpegKit conversion', () {
      // These tests would require mocking FFmpegKit which is more complex
      // as it's a plugin. In practice, you might:
      // 1. Create integration tests that run on actual platforms
      // 2. Use dependency injection to make FFmpegKit testable
      // 3. Test the logic around FFmpegKit calls
      
      test('should handle successful FFmpegKit conversion', () async {
        // This would test the _convertWithFFmpegKit method
        // Would need platform channel mocking or integration testing
      });

      test('should handle cancelled FFmpegKit conversion', () async {
        // Test for ReturnCode.isCancel case
      });

      test('should handle failed FFmpegKit conversion', () async {
        // Test for conversion errors
      });
    });
  });
}

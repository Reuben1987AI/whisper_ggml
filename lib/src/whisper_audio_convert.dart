import 'dart:async';
import 'dart:io' as io;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

/// Class used to convert any audio file to wav
class WhisperAudioConvert {
  ///
  const WhisperAudioConvert({
    required this.audioInput,
    required this.audioOutput,
  });

  /// Input audio file
  final File audioInput;

  /// Output audio file
  /// Overwriten if already exist
  final File audioOutput;

  /// convert [audioInput] to wav file
  Future<File?> convert() async {
    if (Platform.isLinux) {
      return _convertLinux();
    }
    return _convertWithFFmpegKit();
  }

  /// Linux-specific conversion using Process.run
  Future<File?> _convertLinux() async {
    try {
      // Check if ffmpeg is available
      final checkResult = await io.Process.run('which', ['ffmpeg']);
      if (checkResult.exitCode != 0) {
        debugPrint('FFmpeg not found. Please install ffmpeg: sudo apt-get install ffmpeg');
        return null;
      }

      // Run ffmpeg conversion
      final result = await io.Process.run('ffmpeg', [
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

  /// Conversion using FFmpegKit for other platforms
  Future<File?> _convertWithFFmpegKit() async {
    final FFmpegSession session = await FFmpegKit.execute(
      [
        '-y',
        '-i',
        audioInput.path,
        '-ar',
        '16000',
        '-ac',
        '1',
        '-c:a',
        'pcm_s16le',
        audioOutput.path,
      ].join(' '),
    );

    final ReturnCode? returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return audioOutput;
    } else if (ReturnCode.isCancel(returnCode)) {
      debugPrint('File convertion canceled');
    } else {
      debugPrint('File convertion error with returnCode ${returnCode?.getValue()}');
    }

    return null;
  }
}

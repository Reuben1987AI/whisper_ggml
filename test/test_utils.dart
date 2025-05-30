import 'dart:io';
import 'dart:typed_data';

import 'package:universal_io/io.dart' as uio;

/// Test utilities for audio conversion tests
class TestUtils {
  /// Create a minimal WAV file header
  static Uint8List createWavHeader({
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
    int dataSize = 0,
  }) {
    final buffer = ByteData(44);
    
    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    
    // File size - 8
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    
    // WAVE header
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    
    // fmt chunk size
    buffer.setUint32(16, 16, Endian.little);
    
    // Audio format (1 = PCM)
    buffer.setUint16(20, 1, Endian.little);
    
    // Number of channels
    buffer.setUint16(22, channels, Endian.little);
    
    // Sample rate
    buffer.setUint32(24, sampleRate, Endian.little);
    
    // Byte rate
    buffer.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    
    // Block align
    buffer.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    
    // Bits per sample
    buffer.setUint16(34, bitsPerSample, Endian.little);
    
    // data chunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    
    // data chunk size
    buffer.setUint32(40, dataSize, Endian.little);
    
    return buffer.buffer.asUint8List();
  }

  /// Create a test WAV file
  static Future<uio.File> createTestWavFile(String path) async {
    final file = uio.File(path);
    final header = createWavHeader(dataSize: 1600); // 0.1 second of silence
    final data = Uint8List(1600); // Silent audio data
    
    await file.writeAsBytes([...header, ...data]);
    return file;
  }

  /// Create a test MP3 file (minimal valid MP3)
  static Future<uio.File> createTestMp3File(String path) async {
    final file = uio.File(path);
    // Create a more complete MP3 file with ID3 header and valid frame
    final mp3Data = <int>[];
    
    // ID3v2 header
    mp3Data.addAll([
      0x49, 0x44, 0x33, // 'ID3'
      0x04, 0x00, // Version 2.4.0
      0x00, // Flags
      0x00, 0x00, 0x00, 0x00, // Size (0)
    ]);
    
    // MP3 frame header (Layer III, 128 kbps, 44.1 kHz, stereo)
    mp3Data.addAll([
      0xFF, 0xFB, // Frame sync + MPEG1 Layer 3
      0x90, // 128kbps, 44.1kHz
      0x00, // No padding, stereo
    ]);
    
    // Add 417 bytes of silence data (one frame at 128kbps)
    mp3Data.addAll(List.filled(417, 0));
    
    // Add a few more frames for a valid MP3
    for (int i = 0; i < 3; i++) {
      mp3Data.addAll([0xFF, 0xFB, 0x90, 0x00]);
      mp3Data.addAll(List.filled(417, 0));
    }
    
    await file.writeAsBytes(mp3Data);
    return file;
  }
}
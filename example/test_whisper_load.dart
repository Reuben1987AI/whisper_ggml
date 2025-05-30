import 'dart:io';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() async {
  print('Testing whisper library loading...');
  
  try {
    final controller = WhisperController();
    print('WhisperController created successfully');
    
    // Test getting version
    final version = await controller.getVersion();
    print('Whisper version: $version');
    
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
  
  exit(0);
}
import 'dart:ffi';
import 'dart:io';

void main() {
  print('Testing whisper_ggml FFI on Linux...');
  
  try {
    // Try to load the library
    final DynamicLibrary lib = DynamicLibrary.open('libwhisper_ggml_plugin.so');
    print('✓ Library loaded successfully');
    
    // Try to lookup the request function
    final requestFunc = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('request');
    print('✓ Found request function at address: ${requestFunc.address.toRadixString(16)}');
    
    print('\nAll checks passed! The library should work correctly.');
  } catch (e) {
    print('✗ Error: $e');
    exit(1);
  }
}
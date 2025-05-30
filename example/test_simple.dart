import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() async {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Whisper Test')),
        body: TestWidget(),
      ),
    );
  }
}

class TestWidget extends StatefulWidget {
  @override
  _TestWidgetState createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  String status = 'Ready to test';
  
  @override
  void initState() {
    super.initState();
    runTest();
  }
  
  void runTest() async {
    try {
      setState(() => status = 'Creating WhisperController...');
      final controller = WhisperController();
      
      setState(() => status = 'Getting version...');
      final version = await controller.getVersion();
      setState(() => status = 'Version: $version');
      
      await Future.delayed(Duration(seconds: 2));
      
      setState(() => status = 'Setting up model...');
      const model = WhisperModel.base;
      
      setState(() => status = 'Getting model path...');
      final modelPath = await controller.getPath(model);
      setState(() => status = 'Model path: $modelPath');
      
      setState(() => status = 'Checking if model exists...');
      if (!File(modelPath).existsSync()) {
        setState(() => status = 'Model not found, downloading...');
        await controller.downloadModel(model);
        setState(() => status = 'Model downloaded');
      } else {
        setState(() => status = 'Model exists');
      }
      
      setState(() => status = 'Setting up JFK audio...');
      final Directory tempDir = await getTemporaryDirectory();
      final asset = await rootBundle.load('assets/jfk.wav');
      final String jfkPath = "${tempDir.path}/jfk.wav";
      final File convertedFile = await File(jfkPath).writeAsBytes(
        asset.buffer.asUint8List(),
      );
      setState(() => status = 'JFK audio saved to: $jfkPath');
      
      setState(() => status = 'Starting transcription...');
      final result = await controller.transcribe(
        model: model,
        audioPath: convertedFile.path,
        lang: 'en',
      );
      
      if (result?.transcription.text != null) {
        setState(() => status = 'SUCCESS: ${result!.transcription.text}');
      } else {
        setState(() => status = 'FAILED: No transcription result');
      }
      
    } catch (e, stackTrace) {
      setState(() => status = 'ERROR: $e\n$stackTrace');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        status,
        style: TextStyle(fontSize: 14),
      ),
    );
  }
}
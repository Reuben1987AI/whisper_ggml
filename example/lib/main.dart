import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisper ggml example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  /// Modify this model based on your needs

  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final model = WhisperModel.base;
  final AudioRecorder audioRecorder = AudioRecorder();
  final WhisperController whisperController = WhisperController();
  String transcribedText = 'Transcribed text will be displayed here';
  bool isProcessing = false;
  bool isProcessingFile = false;
  bool isListening = false;

  @override
  void initState() {
    initModel();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Whisper ggml example'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  transcribedText,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                child: Tooltip(
                  message: 'Transcribe jfk.wav asset file',
                  child: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    maxRadius: 25,
                    child: isProcessingFile
                        ? const CircularProgressIndicator()
                        : IconButton(
                            onPressed: transcribeJfk,
                            icon: Icon(
                              Icons.folder,
                            ),
                          ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: record,
        tooltip: 'Start listening',
        child: isProcessing
            ? const CircularProgressIndicator()
            : Icon(
                isListening ? Icons.mic_off : Icons.mic,
                color: isListening ? Colors.red : null,
              ),
      ),
    );
  }

  Future<void> initModel() async {
    try {
      debugPrint('=== Initializing model ===');
      /// Try initializing the model from assets
      final bytesBase = await rootBundle.load('assets/ggml-${model.modelName}.bin');
      final modelPathBase = await whisperController.getPath(model);
      debugPrint('Loading model from assets to: $modelPathBase');
      final fileBase = File(modelPathBase);
      await fileBase.writeAsBytes(bytesBase.buffer.asUint8List(bytesBase.offsetInBytes, bytesBase.lengthInBytes));
      debugPrint('Model loaded from assets successfully');
    } catch (e) {
      debugPrint('Assets loading failed: $e');
      /// On error try downloading the model
      debugPrint('Attempting to download model...');
      final downloadPath = await whisperController.downloadModel(model);
      debugPrint('Model downloaded to: $downloadPath');
      
      // Verify the file exists
      final modelPath = await whisperController.getPath(model);
      final exists = File(modelPath).existsSync();
      final size = exists ? File(modelPath).lengthSync() : 0;
      debugPrint('Model file exists: $exists, size: $size bytes');
    }
  }

  Future<void> record() async {
    if (await audioRecorder.hasPermission()) {
      if (await audioRecorder.isRecording()) {
        final audioPath = await audioRecorder.stop();

        if (audioPath != null) {
          debugPrint('Stopped listening.');

          setState(() {
            isListening = false;
            isProcessing = true;
          });

          final result = await whisperController.transcribe(
            model: model,
            audioPath: audioPath,
            lang: 'en',
          );

          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }

          if (result?.transcription.text != null) {
            setState(() {
              transcribedText = result!.transcription.text;
            });
          }
        } else {
          debugPrint('No recording exists.');
        }
      } else {
        debugPrint('Started listening.');

        setState(() {
          isListening = true;
        });

        final Directory appDirectory = await getTemporaryDirectory();
        await audioRecorder.start(const RecordConfig(), path: '${appDirectory.path}/test.m4a');
      }
    }
  }

  Future<void> transcribeJfk() async {
    try {
      debugPrint('=== Starting transcribeJfk ===');
      
      final Directory tempDir = await getTemporaryDirectory();
      debugPrint('Temp dir: ${tempDir.path}');
      
      final asset = await rootBundle.load('assets/jfk.wav');
      debugPrint('Loaded asset, size: ${asset.lengthInBytes} bytes');
      
      final String jfkPath = "${tempDir.path}/jfk.wav";
      final File convertedFile = await File(jfkPath).writeAsBytes(
        asset.buffer.asUint8List(),
      );
      debugPrint('Audio file saved to: $jfkPath');

      setState(() {
        isProcessingFile = true;
        transcribedText = 'Processing...';
      });

      debugPrint('Starting transcription...');
      debugPrint('Model: $model');
      debugPrint('Audio path: ${convertedFile.path}');
      debugPrint('Audio file exists: ${convertedFile.existsSync()}');
      debugPrint('Audio file size: ${convertedFile.lengthSync()} bytes');
      
      final result = await whisperController.transcribe(
        model: model,
        audioPath: convertedFile.path,
        lang: 'en',
      );
      debugPrint('Transcription completed, result: $result');

      setState(() {
        isProcessingFile = false;
      });

      if (result?.transcription.text != null) {
        setState(() {
          transcribedText = result!.transcription.text;
        });
      } else {
        setState(() {
          transcribedText = 'Transcription failed - no result returned';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in transcribeJfk: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        isProcessingFile = false;
        transcribedText = 'Error: $e';
      });
    }
  }
}

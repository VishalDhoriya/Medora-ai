import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import '../base_transcriber/base_transcriber.dart';
import '../../core/services/demo_speech_service.dart';

class DemoTranscriber extends BaseTranscriber {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isDemoMode = false;
  late Directory _dir;
  final Whisper _whisper;

  final List<String> _partialTranscripts = [];
  final Map<int, String> _partialTranscriptsMap = {};
  final List<Future<void>> _transcriptionJobs = [];
  int _chunkCounter = 0;

  DemoTranscriber(this._whisper);

  @override
  Future<void> init() async {
    if (!await _audioRecorder.hasPermission()) {
      throw Exception("Microphone permission not granted");
    }
    _dir = await getApplicationDocumentsDirectory();
  }

  @override
  Future<void> start({bool demoMode = false}) async {
    _isDemoMode = demoMode;
    _isRecording = true;

    if (_isDemoMode) {
      // For demo mode, we don't actually record, just simulate
      print('🎭 Starting demo mode - simulating recording...');
      return;
    }

    // Original recording logic for real recording
    while (_isRecording) {
      final chunkPath =
          '${_dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';
      final chunkIndex = _chunkCounter++;
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: chunkPath,
      );

      await Future.delayed(const Duration(seconds: 30));

      final savedPath = await _audioRecorder.stop();

      if (savedPath != null && _isRecording) {
        print('transcription started');
        final job = _transcribeChunk(savedPath, chunkIndex);
        _transcriptionJobs.add(job);
      }
    }
  }

  @override
  Future<String> stop() async {
    _isRecording = false;

    if (_isDemoMode) {
      // Return demo transcript immediately
      print('🎭 Demo mode - returning demo transcript');
      return DemoSpeechService.getDemoTranscript();
    }

    // Original transcription logic for real recording
    if (await _audioRecorder.isRecording()) {
      final lastPath = await _audioRecorder.stop();
      if (lastPath != null) {
        final lastIndex = _chunkCounter++;
        _transcriptionJobs.add(
          _transcribeChunk(lastPath, lastIndex),
        );
      }
    }

    // Wait for all transcriptions to complete
    await Future.wait(_transcriptionJobs);

    // Sort and join all transcript segments
    final orderedTranscript = _partialTranscriptsMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final transcriptString = orderedTranscript.map((e) => e.value).join('\n');
    print(transcriptString);
    return transcriptString;
  }

  Future<void> _transcribeChunk(String path, int chunkIndex) async {
    try {
      final result = await _whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: path,
          isTranslate: false,
          isNoTimestamps: true,
          splitOnWord: true,
          speedUp: true,
        ),
      );

      if (result.text.isNotEmpty) {
        _partialTranscriptsMap[chunkIndex] = result.text;
        _partialTranscripts.add(result.text);
        print('[Transcription] Chunk $chunkIndex: ${result.text}');
      }
    } catch (e) {
      _partialTranscripts.add('[Transcription error: $e]');
    }
  }
}

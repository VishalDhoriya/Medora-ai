import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

class RecorderWidget extends StatefulWidget {
  const RecorderWidget({Key? key}) : super(key: key);

  @override
  State<RecorderWidget> createState() => _RecorderWidgetState();
}

class _RecorderWidgetState extends State<RecorderWidget> with SingleTickerProviderStateMixin {
  late Whisper _whisper;
  String? _audioPath;
  String? _transcript;
  bool _isTranscribing = false;
  int _recordDuration = 0;
  Timer? _timer;
  bool _isRecording = false;
  bool _isPaused = false;
  late AnimationController _waveController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  // Removed amplitude and timer, no waveform

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Initialize Whisper once for faster transcription
    _whisper = Whisper(
      model: WhisperModel.base,
      downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordDuration = 0;
    });
    _waveController.repeat(reverse: true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = '/storage/emulated/0/Download/rec_$now.wav';
    _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, bitRate: 128000),
      path: path,
    );
    _audioPath = path;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  void _pauseResume() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      _waveController.stop();
      _audioRecorder.pause();
      // Timer keeps running, but we don't increment duration while paused
    } else {
      _waveController.repeat(reverse: true);
      _audioRecorder.resume();
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
      // Recording stopped, audioPath is set
    });
    _waveController.stop();
    _audioRecorder.stop();
    _timer?.cancel();
  }

  Future<void> _transcribeAudio() async {
    if (_audioPath == null) return;
    setState(() {
      _isTranscribing = true;
      _transcript = null;
    });
    try {
      final result = await _whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: _audioPath!,
          isTranslate: false,
          isNoTimestamps: true,
          splitOnWord: false,
        ),
      );
      setState(() {
        _transcript = result.text;
        _isTranscribing = false;
      });
    } catch (e) {
      setState(() {
        _transcript = 'Transcription error: $e';
        _isTranscribing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String durationText = '${twoDigits(_recordDuration ~/ 60)}:${twoDigits(_recordDuration % 60)}';
    return Center(
      child: (!_isRecording && _audioPath == null)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap to start recording',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.mic, color: Colors.white, size: 38),
                    ),
                  ),
                ),
              ],
            )
          : (_isRecording)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      durationText,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pauseResume,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _stopRecording,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.red.shade400, Colors.red.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Recording saved!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.text_snippet),
                      label: const Text('Get Transcript'),
                      onPressed: _isTranscribing ? null : _transcribeAudio,
                    ),
                    if (_isTranscribing) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                    if (_transcript != null) ...[
                      const SizedBox(height: 16),
                      Text('Transcript:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(_transcript!),
                    ],
                  ],
                ),
    );
}

}
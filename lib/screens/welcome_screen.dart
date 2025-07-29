import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'transcribing_screen.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/model_config_service.dart';
import '../services/llm_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _recordDuration = 0;
  Timer? _timer;
  String? _userName;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Whisper? _whisperModel;

  @override
  void initState() {
    super.initState();
    _loadUserAndModel();
    _initializeWhisperModel();
  }

  Future<void> _initializeWhisperModel() async {
    setState(() {
      _whisperModel = Whisper(
        model: WhisperModel.base,
        downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      );
    });
  }

  Future<void> _loadUserAndModel() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('onboard_name') ?? '';
    final model = prefs.getString('onboard_model');
    setState(() {
      _userName = name;
    });
    if (model != null && model.isNotEmpty) {
      await _initializeModel(model);
    }
  }

  Future<void> _initializeModel(String modelName) async {
    final configs = await ModelConfigService.loadModelConfigs();
    ModelConfig config = configs.firstWhere(
      (c) => c.modelName == modelName || c.modelId == modelName,
      orElse: () => configs.first,
    );
    final directory = await getExternalStorageDirectory();
    final modelPath = '${directory!.path}/${config.modelDir}/${config.version}/${config.modelFile}';
    await LlmService.initializeModel(
      config: config,
      modelPath: modelPath,
    );
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadUserAndModel();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (hasPermission) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordDuration = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _recordDuration++;
          });
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    setState(() {
      _isPaused = false;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
    });
    _timer?.cancel();
    const systemPrompt = """"You are a clinical documentation assistant.  
When I send you a doctor–patient transcript, return exactly one JSON object with these keys:  

{
  "Subjective": {
    "CC": string|null,
    "HPI": {
      "Onset": string|null,
      "Location": string|null,
      "Duration": string|null,
      "Characteristics": string|null,
      "AggravatingRelieving": string|null,
      "Timing": string|null,
      "Severity": string|null
    },
    "RoS": [string,...],
    "PMH": [string,...],
    "Meds": [string,...],
    "Allergies": [string,...],
    "Social": [string,...],
    "Family": [string,...]
  },
  "Objective": {
    "Vitals": {
      "Temp": string|null,
      "BP": string|null,
      "HR": string|null,
      "RR": string|null,
      "SpO2": string|null
    },
    "Exam": {
      "General": string|null,
      "HEENT": string|null,
      "Cardio": string|null,
      "Resp": string|null,
      "Abd": string|null,
      "Extremities": string|null,
      "Neuro": string|null
    },
    "LabsImaging": [string,...]
  },
  "Assessment": {
    "Primary": {
      "Name": string|null,
      "ICD10": string|null,
      "Reason": string|null
    },
    "Differentials": [string,...]
  },
  "Plan": {
    "Diagnostics": [string,...],
    "Therapeutics": {
      "Meds": [string,...],
      "NonRx": [string,...]
    },
    "Education": [string,...],
    "FollowUp": string|null
  }
}

Rules:
1. Output only valid JSON—no extra text.
2. If any field is missing in the transcript, use `null` for strings or `[]` for lists.
3. Aim for about 50–60 words total (each field value ≤2 sentences).
4. Preserve the key names and nesting exactly.

BEGIN.
""";
    if (path != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TranscribingScreen(
            whisperModel: _whisperModel,
            audioPath: path,
            systemPrompt: systemPrompt,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String durationText = '${twoDigits(_recordDuration ~/ 60)}:${twoDigits(_recordDuration % 60)}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENKU'),
        actions: [
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.gearSix(PhosphorIconsStyle.regular),
              color: Colors.brown.shade400,
              size: 28,
            ),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Welcome, ${_userName ?? ''}!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            // const SizedBox(height: 20),
            const SizedBox(height: 32),
            Center(
              child: !_isRecording
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Start Consultation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Text(
                          'Tap the button to start recording',
                          style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade300, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _startRecording,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade200, Colors.blue.shade400],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIcons.microphone(PhosphorIconsStyle.regular),
                                color: Colors.black,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Recording in progress', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                        Text(
                          durationText,
                          style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _isPaused ? _resumeRecording : _pauseRecording,
                              child: Container(
                                width: 62,
                                height: 62,
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
                                child: Center(
                                  child: PhosphorIcon(
                                    _isPaused
                                        ? PhosphorIcons.play(PhosphorIconsStyle.regular)
                                        : PhosphorIcons.pause(PhosphorIconsStyle.regular),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            GestureDetector(
                              onTap: _stopRecording,
                              child: Container(
                                width: 62,
                                height: 62,
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
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: PhosphorIcon(
                                    PhosphorIcons.stop(PhosphorIconsStyle.regular),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(_isPaused ? 'Recording paused...' : ''),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

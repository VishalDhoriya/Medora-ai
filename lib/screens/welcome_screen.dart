import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gallery/screens/real_time_transcriber.dart';
import 'package:flutter_gallery/screens/transcribing_timeline_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../services/llm_service.dart';
import '../services/model_config_service.dart';
import 'settings_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _recordDuration = 0;
  Timer? _timer;
  String? _userName;
  String? _selectedModel;
  bool _modelInitialized = false;

  // Recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  // String? _audioPath;

  // Transcription state
  bool _isTranscribing = false;
  String? _transcript;
  Timer? _transcribeDotsTimer;
  int _transcribeDotCount = 0;
  late RealTimeTranscriber transcriber;
  // Whisper? _whisperModel;

  @override
  void initState() {
    super.initState();
    print("✅ initState reached!");
    _loadUserAndModel();
    transcriber = RealTimeTranscriber(
      Whisper(
        model: WhisperModel.baseQ8,
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      ),
    );
    transcriber.init(); // pre-load Whisper + permissions
    // _initializeWhisperModel();
  }

  // Future<void> _initializeWhisperModel() async {
  //   setState(() {
  //     _whisperModel = Whisper(
  //       model: WhisperModel.base,
  //       downloadHost:
  //           "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
  //     );
  //   });
  // }

  Future<void> _loadUserAndModel() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('onboard_name') ?? '';
    final model = prefs.getString('onboard_model');
    setState(() {
      _userName = name;
      _selectedModel = model;
    });
    if (model != null && model.isNotEmpty) {
      await _initializeModel(model);
    }
  }

  Future<void> _initializeModel(String modelName) async {
    // Find the model config by name
    final configs = await ModelConfigService.loadModelConfigs();
    ModelConfig config = configs.firstWhere(
      (c) => c.modelName == modelName || c.modelId == modelName,
      orElse: () => configs.first,
    );
    // Build the model path (same as chat screen)
    final directory = await getExternalStorageDirectory();
    final modelPath =
        '${directory!.path}/${config.modelDir}/${config.version}/${config.modelFile}';
    final success = await LlmService.initializeModel(
      config: config,
      modelPath: modelPath,
    );
    setState(() {
      _modelInitialized = success;
    });
  }

  void _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadUserAndModel(); // Refresh name and model after settings update
  }

  Future<void> _startRecording() async {
    transcriber.start();
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _transcript = null;
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
    // final hasPermission = await _audioRecorder.hasPermission();
    // if (hasPermission) {
    //   final dir = await getApplicationDocumentsDirectory();
    //   final path =
    //       '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    //   await _audioRecorder.start(
    //     const RecordConfig(
    //       encoder: AudioEncoder.wav,
    //       sampleRate: 16000,
    //       bitRate: 128000,
    //     ),
    //     path: path,
    //   );
    //   setState(() {
    //     _isRecording = true;
    //     _isPaused = false;
    //     _recordDuration = 0;
    //     _audioPath = null;
    //     _transcript = null;
    //   });
    //   _timer?.cancel();
    //   _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    //     if (!_isPaused) {
    //       setState(() {
    //         _recordDuration++;
    //       });
    //     }
    //   });
    // } else {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Microphone permission denied')),
    //     );
    //   }
    // }
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
    const systemPrompt = """"{
  "system_prompt": {
    "role": "You are a highly efficient AI medical assistant for on-device use. Your entire output must be a single, extremely brief JSON object.",
    "primary_directive": "Follow the field instructions precisely. Output ONLY the completed JSON template.",
    "rules": {
      "non_medical_case": "If the input is not a medical query, your entire output must be: {\"extraction_success\": false}",
      "medical_case": "If it is a medical query, populate the output_template below, strictly following the field instructions and the output template."
    },
    "field_instructions": {
      "extract_from_text": {
        "instruction": "Find and briefly summarize this information directly from the user's text:",
        "fields": {
          "Reported_Symptoms": "Keyword list of symptoms.",
          "HPI": "1-sentence illness story (<15 words).",
          "Meds_Allergies": "Keyword list of meds & allergies.",
          "Vitals_Exam": "Objective data mentioned (e.g., 'Temp 101F, red throat')."
        }
      },
      "generate_from_analysis": {
        "instruction": "Analyze the extracted data and generate a concise clinical assessment and plan for these fields:",
        "fields": {
          "Symptom_Assessment": "Clinical analysis phrase (<15 words).",
          "Primary_Diagnosis": "Most likely diagnosis (1-5 words).",
          "Differentials": "List of other possible diagnoses.",
          "Diagnostic_Tests": "Keyword list of recommended tests.",
          "Therapeutics": "Keyword list of treatments.",
          "Education": "List of very short advice (<10 words each).",
          "FollowUp": "Brief instruction on when to return."
        }
      }
    },
    "output_template": {
      "extraction_success": true,
      "data": {
        "Subjective": {
          "Reported_Symptoms": [],
          "HPI": null,
          "Meds_Allergies": []
        },
        "Objective": {
          "Vitals_Exam": null
        },
        "Assessment": {
          "Symptom_Assessment": null,
          "Primary_Diagnosis": null,
          "Differentials": []
        },
        "Plan": {
          "Diagnostic_Tests": [],
          "Therapeutics": [],
          "Education": [],
          "FollowUp": null
        }
      }
    }
  }
}""";

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
      _isTranscribing = true;
      _transcript = null;
      _transcribeDotCount = 0;
    });
    _timer?.cancel();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscribingTimelineScreen(
          transcriber: transcriber,
          systemPrompt: systemPrompt,
        ),
      ),
    );

    try {
      final result = await transcriber.stop();
      setState(() {
        _transcript = result;
        _isTranscribing = false;
      });
    } catch (e) {
      setState(() {
        _transcript = 'Transcription error: $e';
        _isTranscribing = false;
      });
    }
    _transcribeDotsTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String durationText =
        '${twoDigits(_recordDuration ~/ 60)}:${twoDigits(_recordDuration % 60)}';
    String transcribingText = 'Transcribing${'.' * _transcribeDotCount}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${_userName ?? ''}!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_selectedModel != null)
              Text(
                'Model: $_selectedModel',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 16),
            if (_modelInitialized)
              const Text(
                'Model initialized!',
                style: TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 32),
            // Recording controls
            if (_isTranscribing)
              Column(
                children: [
                  Text(
                    transcribingText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              )
            else if (_transcript != null)
                Column( //temporary fix to avoid showing transcript in the welcome screen
                  children: [
                    const Text(
                      '',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              // Column(
              //   children: [
              //     const Text(
              //       'Transcript:',
              //       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              //     ),
              //     const SizedBox(height: 12),
              //     SelectableText(
              //       _transcript!,
              //       style: const TextStyle(fontSize: 18),
              //     ),
              //   ],
              // )
            else if (!_isRecording)
              GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 90,
                  height: 90,
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
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.mic, color: Colors.white, size: 44),
                  ),
                ),
              )
            else ...[
              Text(
                durationText,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
                        child: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
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
                      child: const Center(
                        child: Icon(Icons.stop, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_isPaused ? 'Recording paused...' : 'Recording...'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _transcribeDotsTimer?.cancel();
    super.dispose();
  }
}

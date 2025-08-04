import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gallery/screens/real_time_transcriber.dart';
import 'package:flutter_gallery/screens/transcribing_timeline_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../services/database_service.dart';
import '../services/llm_service.dart';
import '../services/model_config_service.dart';
import 'settings_screen.dart';
import 'welcome/widgets/patient_form.dart';
import 'welcome/widgets/patient_info_and_recording.dart';
import 'welcome/widgets/welcome_message.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _recordDuration = 0;
  Timer? _timer;
  String? _userName;

  // Patient state
  Map<String, dynamic>? _patient;
  bool _showPatientForm = false;

  // Previous conversations
  List<CompleteConversationData> _previousConversations = [];
  bool _loadingConversations = false;

  // Previous patients
  List<PatientData> _previousPatients = [];
  bool _loadingPatients = false;

  // Recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;

  // Transcription state
  bool _isTranscribing = false;
  String? _transcript;
  Timer? _transcribeDotsTimer;
  int _transcribeDotCount = 0;
  late RealTimeTranscriber transcriber;

  @override
  void initState() {
    super.initState();
    print("✅ initState reached!");
    _loadUserAndModel();
    _loadPreviousPatients();
    transcriber = RealTimeTranscriber(
      Whisper(
        model: WhisperModel.baseQ8,
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      ),
    );
    transcriber.init(); // pre-load Whisper + permissions
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

  Future<void> _loadPreviousConversations(int patientId) async {
    setState(() {
      _loadingConversations = true;
    });

    try {
      final conversations = await DatabaseService.getPatientConversationHistory(
        patientId,
      );
      setState(() {
        _previousConversations = conversations;
        _loadingConversations = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _loadingConversations = false;
      });
    }
  }

  Future<void> _loadPreviousPatients() async {
    setState(() {
      _loadingPatients = true;
    });

    try {
      final patients = await DatabaseService.getAllPatients();
      setState(() {
        _previousPatients = patients;
        _loadingPatients = false;
      });
    } catch (e) {
      print('Error loading patients: $e');
      setState(() {
        _loadingPatients = false;
      });
    }
  }

  void _selectExistingPatient(PatientData patient) {
    setState(() {
      _patient = {
        'id': patient.id!,
        'name': patient.name,
        'dob': patient.dob,
        'gender': patient.gender,
        'address': patient.address ?? '',
        'isExistingPatient':
            true, // Flag to indicate this is an existing patient
      };
    });
    // Load previous conversations for this patient
    _loadPreviousConversations(patient.id!);
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
    await LlmService.initializeModel(config: config, modelPath: modelPath);
    // Model initialized successfully
  }

  void _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadUserAndModel(); // Refresh name and model after settings update
  }

  Future<void> _startRecording() async {
    // Create a conversation record when starting recording
    if (_patient != null) {
      final conversationId = await DatabaseService.insertConversation(
        ConversationData(
          patientId: _patient!['id'],
          title:
              'Medical Consultation - ${DateTime.now().toString().split(' ')[0]}',
        ),
      );
      // Store conversation ID in patient data for later use
      _patient!['currentConversationId'] = conversationId;
    }

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
    // Calculate patient age for context
    String patientAge = 'Unknown';
    if (_patient != null && _patient!['dob'] != null) {
      final dob = DateTime.tryParse(_patient!['dob']);
      if (dob != null) {
        final age = DateTime.now().difference(dob).inDays ~/ 365;
        patientAge = age.toString();
      }
    }

    final systemPrompt = """"{
  "system_prompt": {
    "role": "You are a highly efficient AI medical assistant for on-device use. Your entire output must be a single, extremely brief JSON object.",
    "patient_context": {
      "name": "${_patient?['name'] ?? 'Unknown'}",
      "age": "$patientAge years",
      "gender": "${_patient?['gender'] ?? 'Unknown'}"
    },
    "primary_directive": "Follow the field instructions precisely. Output ONLY the completed JSON template. Consider the patient context above when analyzing the medical conversation.",
    "rules": {
      "non_medical_case": "If the input is not a medical query, your entire output must be: {\"extraction_success\": false}",
      "medical_case": "If it is a medical query, populate the output_template below, strictly following the field instructions and the output template. Use the patient context (name, age, gender) to provide more accurate medical analysis."
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
        "instruction": "Analyze the extracted data and generate a concise clinical assessment and plan for these fields. Consider the patient's age and gender for age/gender-specific conditions:",
        "fields": {
          "Symptom_Assessment": "Clinical analysis phrase (<15 words).",
          "Primary_Diagnosis": "Most likely diagnosis (1-5 words).",
          "Differentials": "List of other possible diagnoses.",
          "Diagnostic_Tests": "Keyword list of recommended tests.",
          "Therapeutics": "Keyword list of treatments.",
          "Education": "List of very short advice (<10 words each).",
          "FollowUp": "Brief instruction on when to return.",
          "Patient_Summary": "Summarize the consultation in 4–5 short sentences in clear, simple language. Must include: (1) the diagnosed condition, (2) prescribed medications or treatments, (3) any required tests or procedures, and (4) next steps or follow-up instructions. Avoid medical jargon and make it understandable to a layperson.",

        }
      }
    },
      "output_template": {
      "extraction_success": true,
      "Reported_Symptoms": [],
      "HPI": null,
      "Meds_Allergies": [],
      "Vitals_Exam": null,
      "Symptom_Assessment": null,
      "Primary_Diagnosis": null,
      "Differentials": [],
      "Diagnostic_Tests": [],
      "Therapeutics": [],
      "Education": [],
      "FollowUp": null,
      "Patient_Summary": null
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

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscribingTimelineScreen(
          transcriber: transcriber,
          systemPrompt: systemPrompt,
          patient: _patient,
        ),
      ),
    );

    // Reset patient state when returning from transcribing screen
    // This ensures user goes back to welcome screen instead of patient info
    setState(() {
      _patient = null;
      _isTranscribing = false;
    });

    // Refresh the patient list to show any updates
    _loadPreviousPatients();

    try {
      final transcribeResult = await transcriber.stop();
      setState(() {
        _transcript = transcribeResult;
      });
    } catch (e) {
      setState(() {
        _transcript = 'Transcription error: $e';
      });
    }
    _transcribeDotsTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content area
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_showPatientForm) {
      return PatientForm(
        onPatientCreated: (patientData) {
          setState(() {
            _patient = patientData;
            _showPatientForm = false;
          });
          _loadPreviousConversations(patientData['id']);
        },
        onCancel: () {
          setState(() {
            _showPatientForm = false;
          });
        },
      );
    } else if (_patient != null) {
      return PatientInfoAndRecording(
        patient: _patient!,
        isRecording: _isRecording,
        isPaused: _isPaused,
        isTranscribing: _isTranscribing,
        recordDuration: _recordDuration,
        transcribeDotCount: _transcribeDotCount,
        transcript: _transcript,
        previousConversations: _previousConversations,
        loadingConversations: _loadingConversations,
        onStartRecording: _startRecording,
        onPauseRecording: _pauseRecording,
        onResumeRecording: _resumeRecording,
        onStopRecording: _stopRecording,
        onBack: () {
          setState(() {
            _patient = null;
          });
        },
      );
    } else {
      return WelcomeMessage(
        previousPatients: _previousPatients,
        loadingPatients: _loadingPatients,
        onSelectPatient: _selectExistingPatient,
        onAddNewPatient: () {
          setState(() {
            _showPatientForm = true;
          });
        },
        userName: _userName, // Pass the userName
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _transcribeDotsTimer?.cancel();
    super.dispose();
  }
}

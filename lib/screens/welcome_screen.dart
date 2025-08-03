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
// import 'patient_form_screen.dart';

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

  // Patient state
  Map<String, dynamic>? _patient;
  bool _showPatientForm = false;

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
      "FollowUp": null
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
          patient: _patient,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show welcome message when no patient is added and form is not shown
          if (!_showPatientForm && _patient == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_userName ?? ''}!',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Show patient form or recording controls
                    if (_showPatientForm)
                      _buildPatientForm()
                    else if (_patient != null)
                      _buildPatientInfoAndRecording()
                    else
                      _buildWelcomeMessage(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !_showPatientForm && _patient == null ? Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            setState(() {
              _showPatientForm = true;
            });
          },
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 8,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          icon: const Icon(Icons.add, size: 24, color: Colors.white),
          label: const Text(
            'New Patient',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: const Column(
        children: [
          Text(
            'Please add a new patient to start',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientForm() {
    final nameController = TextEditingController();
    final dobController = TextEditingController();
    final addressController = TextEditingController();
    String selectedGender = 'Male';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Patient Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Name Field
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          // DOB Field
          TextFormField(
            controller: dobController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.cake),
              hintText: 'YYYY-MM-DD',
            ),
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                dobController.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Gender Field
          StatefulBuilder(
            builder: (context, setModalState) => DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              items: ['Male', 'Female', 'Other'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setModalState(() {
                  selectedGender = newValue!;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Address Field
          TextFormField(
            controller: addressController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 32),
          
          // Start Conversation Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
              if (nameController.text.isNotEmpty && 
                  dobController.text.isNotEmpty) {
                setState(() {
                  _patient = {
                    'name': nameController.text,
                    'dob': dobController.text,
                    'gender': selectedGender,
                    'address': addressController.text,
                  };
                  _showPatientForm = false;
                });
                // Start recording immediately
                _startRecording();
              }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 54),
                maximumSize: const Size(220, 54),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Start Conversation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Cancel Button
          TextButton(
            onPressed: () {
              setState(() {
                _showPatientForm = false;
              });
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoAndRecording() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String durationText =
        '${twoDigits(_recordDuration ~/ 60)}:${twoDigits(_recordDuration % 60)}';
    String transcribingText = 'Transcribing${'.' * _transcribeDotCount}';

    int? _calculateAge(String dob) {
      try {
        final parts = dob.split('-');
        if (parts.length != 3) return null;
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final birthDate = DateTime(year, month, day);
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        return age;
      } catch (_) {
        return null;
      }
    }
    return Column(
      children: [
        // Enhanced Patient Header Card - Larger during recording
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF1976D2).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Larger Patient Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _patient!['name'].toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Patient Info - Larger fonts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _patient!['name'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_calculateAge(_patient!['dob']) ?? '-'} years old • ${_patient!['gender']}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Recording Controls
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
          const Column(
            children: [
              Text(
                '',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          )
        else if (!_isRecording)
          const SizedBox(height: 24) // Just show spacing when patient is added but not recording
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
    );
  }

  // Compact Patient Header Widget for transcribing page
  Widget buildCompactPatientHeader(Map<String, dynamic> patient, {bool showDropdown = true}) {
    bool _isExpanded = false;
    
    int? calculateAge(String dob) {
      try {
        final parts = dob.split('-');
        if (parts.length != 3) return null;
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final birthDate = DateTime(year, month, day);
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        return age;
      } catch (_) {
        return null;
      }
    }

    return StatefulBuilder(
      builder: (context, setState) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main header row
            InkWell(
              onTap: showDropdown ? () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              } : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Compact Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          patient['name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Compact Patient Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            patient['name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                              height: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${calculateAge(patient['dob']) ?? '-'} years • ${patient['gender']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Dropdown arrow
                    if (showDropdown)
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
            
            // Expanded details
            if (_isExpanded && showDropdown)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.grey.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    
                    // DOB
                    if (patient['dob'] != null && patient['dob'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Date of Birth: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              patient['dob'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Address
                    if (patient['address'] != null && patient['address'].isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Address: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              patient['address'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
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
    _transcribeDotsTimer?.cancel();
    super.dispose();
  }
}

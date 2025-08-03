import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
// import 'transcribing_screen.dart';
import 'real_time_transcriber.dart';
import '../services/llm_service.dart';
// import 'transcribing_screen.dart';

/// A beautiful timeline UI that uses TranscribingScreen as a backend module.
/// It launches the process, listens for transcript and LLM results, and displays each step in a timeline with gradients and expandable cards.
class TranscribingTimelineScreen extends StatefulWidget {
  final String systemPrompt;
  final RealTimeTranscriber transcriber;
  final Map<String, dynamic>? patient;
  
  const TranscribingTimelineScreen({
    super.key,
    required this.transcriber,
    required this.systemPrompt,
    this.patient,
  });

  @override
  State<TranscribingTimelineScreen> createState() => _TranscribingTimelineScreenState();
}

class _StepData {
  final String label;
  final IconData icon;
  final bool completed;
  final Duration? duration;
  final String? content;
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget? customExpandedContent; // Add custom content widget
  _StepData({
    required this.label,
    required this.icon,
    this.completed = false,
    this.duration,
    this.content,
    this.expanded = false,
    this.onToggle,
    this.customExpandedContent,
  });
}

class _TranscribingTimelineScreenState extends State<TranscribingTimelineScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _soapScrollController = ScrollController();
  String? _transcript;
  String? _llmResponse;
  Map<String, dynamic>? _parsedLlmJson;
  bool _transcribeDone = false;
  bool _llmDone = false;
  bool _showTranscript = false;
  bool _showLlm = false;
  bool _showSystemThoughts = false;
  Duration? _transcribeDuration;
  Duration? _llmDuration;
  DateTime? _stepStart;
  Duration _liveTranscribe = Duration.zero;
  Duration _liveLlm = Duration.zero;
  Timer? _timer;
  // int _step = 0; // 0: transcribe, 1: llm

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainScrollController.dispose();
    _soapScrollController.dispose();
    super.dispose();
  }

  void _startLiveTimer() {
    if (_llmDone) {
      print('⏹️ Not starting timer: LLM already done');
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Cancel timer if LLM is done (regardless of transcribe state)
      if (_llmDone) {
        print('⏹️ Timer cancelled: LLM done');
        _timer?.cancel();
        return;
      }
      setState(() {
        if (!_transcribeDone) {
          _liveTranscribe = DateTime.now().difference(_stepStart!);
        } else if (!_llmDone) {
          _liveLlm = DateTime.now().difference(_stepStart!);
        }
      });
    });
  }

  Future<void> _startProcess() async {
    // Step 1: Transcribe
    _stepStart = DateTime.now();
    _liveTranscribe = Duration.zero;
    _startLiveTimer();
    print('🟡 Awaiting transcriber.stop()...');
    final transcript = await widget.transcriber.stop();
    print('🟢 transcriber.stop() completed, transcript: $transcript');
    setState(() {
      print('🟢 setState: Marking _transcribeDone = true');
      _transcript = transcript;
      _transcribeDone = true;
      _transcribeDuration = DateTime.now().difference(_stepStart!);
      _stepStart = DateTime.now();
      _liveLlm = Duration.zero;
    });
    
    // Step 2: LLM (async - handled by stream listener)
    final prompt = "${widget.systemPrompt}\n$transcript";
    String llmResponse = '';
    final stream = LlmService.getInferenceStream();
    print('🔄 Setting up LLM stream listener...');
    
    StreamSubscription? sub;
    sub = stream.listen((result) {
      print('📨 Stream event received: isDone=${result.isDone}, partialResult length=${result.partialResult.length}');
      if (result.isDone) {
        final llmDuration = DateTime.now().difference(_stepStart!);
        print('✅ LLM is done! Duration: ${llmDuration.inSeconds}s, partial: ${result.partialResult.length} chars');
        
        // Cancel timer first
        _timer?.cancel();
        print('⏹️ Timer cancelled due to LLM completion');
        
        // Update response
        llmResponse += result.partialResult;
        
        // Parse JSON
        Map<String, dynamic>? parsedJson;
        try {
          parsedJson = _parseJson(llmResponse);
          print('✅ JSON parsed successfully: ${parsedJson != null}');
          if (parsedJson != null) {
            print('📄 Parsed JSON: $parsedJson');
          }
        } catch (e) {
          print('❌ JSON parsing failed: $e');
          parsedJson = null;
        }
        
        // Update state
        setState(() {
          _llmDone = true;
          _llmResponse = llmResponse;
          _llmDuration = llmDuration;
          _liveLlm = llmDuration; // Freeze the live timer
          _parsedLlmJson = parsedJson;
        });
        
        print('🔄 State updated. _llmDone=$_llmDone, _llmResponse length=${_llmResponse?.length}, _parsedLlmJson=$_parsedLlmJson');
        
        // Cancel subscription after processing
        sub?.cancel();
      } else {
        print('📨 Partial result: ${result.partialResult}');
        setState(() {
          llmResponse += result.partialResult;
        });
      }
    }, onError: (error) {
      print('❌ Stream error: $error');
    }, onDone: () {
      print('🏁 Stream closed');
    });
    
    print('🚀 Starting LLM generation...');
    // Start the generation but don't wait for it to complete
    // The completion will be handled by the stream listener
    LlmService.generateResponse(prompt);
    print('✅ LLM generation method called (not waiting for completion)');
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;
      final jsonString = text.substring(jsonStart, jsonEnd + 1).trim();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building UI - _transcribeDone=$_transcribeDone, _llmDone=$_llmDone, _parsedLlmJson=${_parsedLlmJson != null}');

    final steps = <_StepData>[
      // Show individual steps only while they're in progress
      if (!(_transcribeDone && _llmDone)) ...[
        _StepData(
          label: 'Transcription',
          icon: Icons.mic,
          completed: _transcribeDone,
          duration: _transcribeDone ? _transcribeDuration : _liveTranscribe,
          content: _transcribeDone ? _transcript : 'Transcribing...',
          expanded: _showTranscript,
          onToggle: () => setState(() => _showTranscript = !_showTranscript),
        ),
        _StepData(
          label: 'LLM Analysis',
          icon: Icons.auto_awesome,
          completed: _llmDone,
          duration: _llmDone ? _llmDuration : _liveLlm,
          content: _llmDone ? (_llmResponse ?? 'No response.') : 'Analyzing...',
          expanded: _showLlm,
          onToggle: () => setState(() => _showLlm = !_showLlm),
        ),
      ] else
        // Show System Thoughts when both processes are complete
        _StepData(
          label: 'System Thoughts',
          icon: Icons.psychology,
          completed: true,
          duration: _getCumulativeDuration(),
          content: _buildSystemThoughtsContent(),
          expanded: _showSystemThoughts,
          onToggle: () => setState(() => _showSystemThoughts = !_showSystemThoughts),
          customExpandedContent: _buildSystemThoughtsExpandedContent(),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Edit')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _mainScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _mainScrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Header at the top
                    if (widget.patient != null)
                      _buildCompactPatientHeader(widget.patient!),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TimelineGradient(steps: steps),
                          const SizedBox(height: 24),
                          if (_llmDone && _parsedLlmJson != null)
                            _buildSoapSummary(_parsedLlmJson!),
                          // Add extra space at the bottom for scroll
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Duration? _getCumulativeDuration() {
    if (_transcribeDuration != null && _llmDuration != null) {
      return Duration(
        milliseconds: _transcribeDuration!.inMilliseconds + _llmDuration!.inMilliseconds
      );
    }
    return null;
  }

  String _buildSystemThoughtsContent() {
    // This will be used to show both transcription and LLM analysis in expandable format
    return 'Click to view transcription and analysis details';
  }

  Widget _buildSystemThoughtsExpandedContent() {
    return Column(
      children: [
        // Mini Timeline inside System Thoughts
        Column(
          children: [
            // Transcription Timeline Item
            _buildMiniTimelineItem(
              label: 'Transcription',
              icon: Icons.mic,
              duration: _transcribeDuration,
              content: _transcript ?? 'No transcription available.',
              isFirst: true,
              isLast: false,
            ),
            
            // LLM Analysis Timeline Item
            _buildMiniTimelineItem(
              label: 'LLM Analysis',
              icon: Icons.auto_awesome,
              duration: _llmDuration,
              content: _llmResponse ?? 'No LLM analysis available.',
              isFirst: false,
              isLast: false,
            ),

            // SOAP Note Generation Timeline Item
            _buildMiniTimelineItem(
              label: 'SOAP Note Generation',
              icon: Icons.description,
              duration: null, // No time display
              content: 'SOAP note generated successfully from analysis.',
              isFirst: false,
              isLast: true, // No line below this step
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniTimelineItem({
    required String label,
    required IconData icon,
    required Duration? duration,
    required String content,
    required bool isFirst,
    required bool isLast,
  }) {
    const Color accent = Color(0xFF1976D2);
    const Color borderColor = Color(0xFF1976D2);
    const Color bgColor = Color(0xFFF4F9FE);

    return Padding(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline indicator column
            Container(
              width: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Connecting line going down (to next item)
                  if (!isLast)
                    Positioned(
                      top: 18, // Start from center of dot
                      left: 11, // Center the line
                      right: 11,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: borderColor.withOpacity(0.8),
                      ),
                    ),
                  // Connecting line coming from above (from previous item)
                  if (!isFirst)
                    Positioned(
                      top: 0,
                      left: 11, // Center the line
                      right: 11, 
                      height: 18, // Fixed height to reach exactly to dot center
                      child: Container(
                        width: 2,
                        color: borderColor.withOpacity(0.8),
                      ),
                    ),
                  // Dot positioned at top of content
                  Positioned(
                    top: 12,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor.withOpacity(0.18), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(icon, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222B45),
                          ),
                        ),
                        if (duration != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '(${duration.inSeconds}s)',
                              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Content
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor.withOpacity(0.10)),
                      ),
                      child: SelectableText(
                        content,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF222B45)),
                        minLines: 1,
                        maxLines: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoapSummary(Map<String, dynamic> json) {
    if (json['extraction_success'] == false) {
      return Card(
        color: Colors.red[50],
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Not a medical conversation.',
                  style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Flat format: fields are at the top level
    final data = json;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOAP Note', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap any section to expand/collapse', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final _expanded = List<bool>.filled(4, true);
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  return SizedBox(
                    width: double.infinity,
                    child: Scrollbar(
                      controller: _soapScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _soapScrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // Subjective
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F9FE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.18), width: 1.2),
                                ),
                                child: ExpansionPanelList(
                                  elevation: 0,
                                  expandedHeaderPadding: EdgeInsets.zero,
                                  expansionCallback: (int index, bool isExpanded) {
                                    setLocalState(() {
                                      _expanded[0] = !_expanded[0];
                                    });
                                  },
                                  children: [
                                    ExpansionPanel(
                                      canTapOnHeader: true,
                                      isExpanded: _expanded[0],
                                      backgroundColor: Colors.transparent,
                                      headerBuilder: (context, isExpanded) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Subjective',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      body: Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _listField('Reported Symptoms', data['Reported_Symptoms']),
                                              _field('HPI', data['HPI']),
                                              _listField('Meds & Allergies', data['Meds_Allergies']),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Objective
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F9FE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.18), width: 1.2),
                                ),
                                child: ExpansionPanelList(
                                  elevation: 0,
                                  expandedHeaderPadding: EdgeInsets.zero,
                                  expansionCallback: (int index, bool isExpanded) {
                                    setLocalState(() {
                                      _expanded[1] = !_expanded[1];
                                    });
                                  },
                                  children: [
                                    ExpansionPanel(
                                      canTapOnHeader: true,
                                      isExpanded: _expanded[1],
                                      backgroundColor: Colors.transparent,
                                      headerBuilder: (context, isExpanded) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Objective',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      body: Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _field('Vitals & Exam', data['Vitals_Exam']),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Assessment
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F9FE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.18), width: 1.2),
                                ),
                                child: ExpansionPanelList(
                                  elevation: 0,
                                  expandedHeaderPadding: EdgeInsets.zero,
                                  expansionCallback: (int index, bool isExpanded) {
                                    setLocalState(() {
                                      _expanded[2] = !_expanded[2];
                                    });
                                  },
                                  children: [
                                    ExpansionPanel(
                                      canTapOnHeader: true,
                                      isExpanded: _expanded[2],
                                      backgroundColor: Colors.transparent,
                                      headerBuilder: (context, isExpanded) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Assessment',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      body: Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _field('Symptom Assessment', data['Symptom_Assessment']),
                                              _field('Primary Diagnosis', data['Primary_Diagnosis']),
                                              _listField('Differentials', data['Differentials']),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Plan
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F9FE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.18), width: 1.2),
                                ),
                                child: ExpansionPanelList(
                                  elevation: 0,
                                  expandedHeaderPadding: EdgeInsets.zero,
                                  expansionCallback: (int index, bool isExpanded) {
                                    setLocalState(() {
                                      _expanded[3] = !_expanded[3];
                                    });
                                  },
                                  children: [
                                    ExpansionPanel(
                                      canTapOnHeader: true,
                                      isExpanded: _expanded[3],
                                      backgroundColor: Colors.transparent,
                                      headerBuilder: (context, isExpanded) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Plan',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      body: Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _listField('Diagnostic Tests', data['Diagnostic_Tests']),
                                              _listField('Therapeutics', data['Therapeutics']),
                                              _listField('Education', data['Education']),
                                              _field('Follow Up', data['FollowUp']),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Compact Patient Header Widget
  Widget _buildCompactPatientHeader(Map<String, dynamic> patient) {
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
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
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
            if (_isExpanded)
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

  Widget _field(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RichText(
            text: TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: (value == null || (value is String && value.trim().isEmpty)) ? 'None' : value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: (value == null || (value is String && value.trim().isEmpty)) ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          );
        },
      ),
    );
  }

  Widget _listField(String label, dynamic value) {
    if (value == null || (value is List && value.isEmpty)) {
      // Use the same style as non-empty, but 'None' in grey
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RichText(
              text: TextSpan(
                text: '$label: ',
                style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: 'None',
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.grey),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            );
          },
        ),
      );
    }
    if (value is List) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ...value.map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 7, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 16), softWrap: true, overflow: TextOverflow.ellipsis, maxLines: 3)),
                    ],
                  ),
                )),
          ],
        ),
      );
    }
    // fallback for non-list
    return _field(label, value);
  }
}

class _TimelineGradient extends StatelessWidget {
  final List<_StepData> steps;
  const _TimelineGradient({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _TimelineStepCard(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStepCard extends StatelessWidget {
  final _StepData step;
  final bool isFirst;
  final bool isLast;
  const _TimelineStepCard({required this.step, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    // Color scheme
    final Color accent = step.completed ? Color(0xFF1976D2) : Color(0xFFB0BEC5); // blueAccent or grey
    final Color borderColor = step.completed ? Color(0xFF1976D2) : Color(0xFFB0BEC5);
    final Color bgColor = step.completed ? Color(0xFFF4F9FE) : Color(0xFFF7F9FB);

    final bool isCollapsed = !(step.expanded && (step.content != null || step.customExpandedContent != null));
    final bool isSystemThoughts = step.label == 'System Thoughts';
    
    return Padding(
      padding: EdgeInsets.zero, // Remove all gaps between timeline items
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hide timeline indicator for System Thoughts
            if (!isSystemThoughts)
              Container(
                width: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Full vertical line (except for first/last)
                    if (!(isFirst && isLast))
                      Positioned.fill(
                        child: Container(
                          width: 2,
                          color: isFirst 
                            ? Colors.transparent 
                            : isLast 
                              ? borderColor.withOpacity(0.8)
                              : borderColor.withOpacity(0.8), // Continuous connection
                        ),
                      ),
                    // Dot
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (!isSystemThoughts) const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: isCollapsed ? 4 : 6), // Small margin for card spacing
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withOpacity(0.18), width: 1.2),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isCollapsed ? 12 : 14,
                    right: isCollapsed ? 6 : 14,
                    top: isCollapsed ? 1 : 14,
                    bottom: isCollapsed ? 1 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              step.label,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF222B45)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (step.duration != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                '(${step.duration!.inSeconds}s)',
                                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                              ),
                            ),
                          if (step.completed && step.content != null)
                            IconButton(
                              icon: Icon(step.expanded ? Icons.expand_less : Icons.expand_more, color: Color(0xFF90A4AE)),
                              onPressed: step.onToggle,
                              splashRadius: 18,
                            ),
                        ],
                      ),
                      if (step.expanded && (step.content != null || step.customExpandedContent != null))
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor.withOpacity(0.10)),
                          ),
                          child: step.customExpandedContent ?? SelectableText(
                            step.content!,
                            style: const TextStyle(fontSize: 15, color: Color(0xFF222B45)),
                            minLines: 1,
                            maxLines: 8,
                            textAlign: TextAlign.left,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

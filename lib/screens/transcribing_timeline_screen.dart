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
  const TranscribingTimelineScreen({
    super.key,
    required this.transcriber,
    required this.systemPrompt,
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
  _StepData({
    required this.label,
    required this.icon,
    this.completed = false,
    this.duration,
    this.content,
    this.expanded = false,
    this.onToggle,
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
                child: Padding(
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
              ),
            );
          },
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
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const Text('No extracted data.', style: TextStyle(color: Colors.red));
    }
    final List<String> sections = ['Subjective', 'Objective', 'Assessment', 'Plan'];
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
              final _expanded = List<bool>.filled(sections.length, true);
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionPanelList(
                                elevation: 0,
                                expandedHeaderPadding: EdgeInsets.zero,
                                expansionCallback: (int index, bool isExpanded) {
                                  setLocalState(() {
                                    _expanded[index] = !_expanded[index];
                                  });
                                },
                                children: [
                                  // Subjective
                                  ExpansionPanel(
                                    canTapOnHeader: true,
                                    isExpanded: _expanded[0],
                                    backgroundColor: const Color(0xFFF4F9FE),
                                    headerBuilder: (context, isExpanded) => Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF4F9FE),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Subjective',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                                            _listField('Reported Symptoms', data['Subjective']?['Reported_Symptoms']),
                                            _field('HPI', data['Subjective']?['HPI']),
                                            _listField('Meds & Allergies', data['Subjective']?['Meds_Allergies']),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionPanelList(
                                elevation: 0,
                                expandedHeaderPadding: EdgeInsets.zero,
                                expansionCallback: (int index, bool isExpanded) {
                                  setLocalState(() {
                                    _expanded[index + 1] = !_expanded[index + 1];
                                  });
                                },
                                children: [
                                  // Objective
                                  ExpansionPanel(
                                    canTapOnHeader: true,
                                    isExpanded: _expanded[1],
                                    backgroundColor: const Color(0xFFF4F9FE),
                                    headerBuilder: (context, isExpanded) => Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF4F9FE),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Objective',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                                              _field('Vitals & Exam', data['Objective']?['Vitals_Exam']),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionPanelList(
                                elevation: 0,
                                expandedHeaderPadding: EdgeInsets.zero,
                                expansionCallback: (int index, bool isExpanded) {
                                  setLocalState(() {
                                    _expanded[index + 2] = !_expanded[index + 2];
                                  });
                                },
                                children: [
                                  // Assessment
                                  ExpansionPanel(
                                    canTapOnHeader: true,
                                    isExpanded: _expanded[2],
                                    backgroundColor: const Color(0xFFF4F9FE),
                                  headerBuilder: (context, isExpanded) => Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF4F9FE),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Assessment',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                                            _field('Symptom Assessment', data['Assessment']?['Symptom_Assessment']),
                                            _field('Primary Diagnosis', data['Assessment']?['Primary_Diagnosis']),
                                            _listField('Differentials', data['Assessment']?['Differentials']),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionPanelList(
                                elevation: 0,
                                expandedHeaderPadding: EdgeInsets.zero,
                                expansionCallback: (int index, bool isExpanded) {
                                  setLocalState(() {
                                    _expanded[index + 3] = !_expanded[index + 3];
                                  });
                                },
                                children: [
                                  // Plan
                                  ExpansionPanel(
                                    canTapOnHeader: true,
                                    isExpanded: _expanded[3],
                                    backgroundColor: const Color(0xFFF4F9FE),
                                    headerBuilder: (context, isExpanded) => Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF4F9FE),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Plan',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                                            _listField('Diagnostic Tests', data['Plan']?['Diagnostic_Tests']),
                                            _listField('Therapeutics', data['Plan']?['Therapeutics']),
                                            _listField('Education', data['Plan']?['Education']),
                                            _field('Follow Up', data['Plan']?['FollowUp']),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 10),
            ...children,
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
    final gradient = LinearGradient(
      colors: step.completed
          ? [Colors.blueAccent, Colors.lightBlueAccent]
          : [Colors.grey[300]!, Colors.grey[100]!],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst)
              Container(width: 2, height: 16, decoration: BoxDecoration(gradient: gradient)),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: step.completed ? gradient : null,
                color: step.completed ? null : Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: Icon(step.icon, color: Colors.white, size: 18),
            ),
            if (!isLast)
              Container(width: 2, height: 32, decoration: BoxDecoration(gradient: gradient)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(step.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (step.duration != null)
                        Text(
                          '(${step.duration!.inSeconds}s)',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      if (step.completed && step.content != null)
                        IconButton(
                          icon: Icon(step.expanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: step.onToggle,
                        ),
                    ],
                  ),
                  if (step.expanded && step.content != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue[50]!, Colors.blue[100]!]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(step.content!, style: const TextStyle(fontSize: 16)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import '../base_transcriber/base_transcriber.dart';
import 'widgets/compact_patient_header.dart';
import 'widgets/timeline_components.dart';
import 'widgets/system_thoughts.dart';
import 'widgets/editable_soap_summary.dart';
import 'utils/timeline_utils.dart';
import 'utils/timeline_process_controller.dart';
import '../../core/services/database_service.dart';

/// A beautiful timeline UI that uses TranscribingScreen as a backend module.
/// It launches the process, listens for transcript and LLM results, and displays each step in a timeline with gradients and expandable cards.
class TranscribingTimelineScreen extends StatefulWidget {
  final String systemPrompt;
  final BaseTranscriber transcriber;
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

class _TranscribingTimelineScreenState extends State<TranscribingTimelineScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _soapScrollController = ScrollController();
  
  late TimelineProcessController _processController;
  bool _systemThoughtsExpanded = true; // Start expanded during process
  Timer? _autoCollapseTimer;

  @override
  void initState() {
    super.initState();
    _processController = TimelineProcessController(
      transcriber: widget.transcriber,
      systemPrompt: widget.systemPrompt,
      patient: widget.patient,
    );
    
    // Setup callbacks
    _processController.onTranscribeUpdate = (transcript, transcribeDone, transcribeDuration, liveTranscribe) {
      setState(() {});
    };
    
    _processController.onLlmUpdate = (llmResponse, parsedJson, llmDone, llmDuration, liveLlm) {
      setState(() {});
    };
    
    _processController.onProcessComplete = () {
      // Auto-collapse System Thoughts when both processes are complete
      _autoCollapseTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _systemThoughtsExpanded = false; // Collapse when complete
          });
          print('🔄 Auto-collapsed System Thoughts when complete');
        }
      });
    };
    
    _startProcess();
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _processController.dispose();
    _mainScrollController.dispose();
    _soapScrollController.dispose();
    super.dispose();
  }

  void _saveSoapData(Map<String, dynamic> updatedData) async {
    // Update the controller's parsed JSON with the edited data
    _processController.updateParsedLlmJson(updatedData);
    
    // Save the edited data back to the database
    if (widget.patient != null && widget.patient!['currentConversationId'] != null) {
      try {
        // Get the existing LLM output data
        final existingLlmOutput = await DatabaseService.getLlmOutputByConversation(
          widget.patient!['currentConversationId']
        );
        
        if (existingLlmOutput != null) {
          // Update the parsed JSON with the edited data
          final updatedLlmOutput = LlmOutputData(
            id: existingLlmOutput.id,
            conversationId: existingLlmOutput.conversationId,
            rawOutput: existingLlmOutput.rawOutput,
            parsedJson: updatedData, // Use the edited data
            extractionSuccess: existingLlmOutput.extractionSuccess,
            duration: existingLlmOutput.duration,
            createdAt: existingLlmOutput.createdAt,
          );
          
          // Save to database
          await DatabaseService.updateLlmOutput(updatedLlmOutput);
          print('💾 Edited SOAP data saved to database');
        }
      } catch (e) {
        print('❌ Error saving SOAP data to database: $e');
      }
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOAP note changes saved successfully!'),
        backgroundColor: Color(0xFF1976D2),
        duration: Duration(seconds: 2),
      ),
    );
    
    // You can add additional save logic here, such as:
    // - Sending to a server
    // - Updating patient records
    print('💾 SOAP data saved: ${updatedData.keys.join(', ')}');
  }

  void _startProcess() {
    _processController.startProcess();
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building UI - transcribeDone=${_processController.transcribeDone}, llmDone=${_processController.llmDone}, systemThoughtsExpanded=$_systemThoughtsExpanded, parsedLlmJson=${_processController.parsedLlmJson != null}');

    final steps = <StepData>[
      // Always show System Thoughts
      StepData(
        label: 'System Thoughts',
        icon: Icons.psychology,
        completed: _processController.llmDone, // Completed when LLM is done
        duration: _processController.getCumulativeDuration(),
        content: _buildSystemThoughtsContent(),
        expanded: _systemThoughtsExpanded, // Use separate expansion state
        onToggle: () => setState(() => _systemThoughtsExpanded = !_systemThoughtsExpanded), // Toggle expansion
        customExpandedContent: SystemThoughts(
          transcribeDone: _processController.transcribeDone,
          llmDone: _processController.llmDone,
          liveTranscribe: _processController.liveTranscribe,
          liveLlm: _processController.liveLlm,
          transcribeDuration: _processController.transcribeDuration,
          llmDuration: _processController.llmDuration,
          transcript: _processController.transcript,
          llmResponse: _processController.llmResponse,
        ),
      ),
    ];
    
    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation only if both processes are complete
        return _processController.transcribeDone && _processController.llmDone;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review & Edit'),
          leading: _processController.transcribeDone && _processController.llmDone
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : Container(), // Hide back button during processing
        ),
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
                      CompactPatientHeader(patient: widget.patient!),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TimelineGradient(steps: steps),
                          const SizedBox(height: 24),
                          if (_processController.llmDone && _processController.parsedLlmJson != null)
                            EditableSoapSummary(
                              json: _processController.parsedLlmJson!,
                              soapScrollController: _soapScrollController,
                              onSave: _saveSoapData,
                              patient: widget.patient,
                            ),
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
      ),
    );
  }

  String _buildSystemThoughtsContent() {
    if (!_processController.transcribeDone) {
      return 'Converting speech to text...';
    } else if (!_processController.llmDone) {
      return 'Analyzing medical content and generating insights...';
    } else {
      return 'All processes complete. Click to view details.';
    }
  }
}

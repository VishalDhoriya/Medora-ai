import 'package:flutter/material.dart';
import '../../../../core/services/database_service.dart';
import '../utils/welcome_utils.dart';
import 'soap_analysis_section.dart';
import 'conversation_card.dart';

class PatientInfoAndRecording extends StatefulWidget {
  final Map<String, dynamic> patient;
  final bool isRecording;
  final bool isPaused;
  final bool isTranscribing;
  final int recordDuration;
  final int transcribeDotCount;
  final String? transcript;
  final List<CompleteConversationData> previousConversations;
  final bool loadingConversations;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;
  final VoidCallback? onStartDemo; // Add demo callback
  final VoidCallback? onBack; // Add back callback

  const PatientInfoAndRecording({
    super.key,
    required this.patient,
    required this.isRecording,
    required this.isPaused,
    required this.isTranscribing,
    required this.recordDuration,
    required this.transcribeDotCount,
    this.transcript,
    required this.previousConversations,
    required this.loadingConversations,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    this.onStartDemo, // Add demo callback
    this.onBack, // Add back callback
  });

  @override
  State<PatientInfoAndRecording> createState() => _PatientInfoAndRecordingState();
}

class _PatientInfoAndRecordingState extends State<PatientInfoAndRecording> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String durationText = WelcomeUtils.formatRecordingDuration(widget.recordDuration);
    String transcribingText = 'Transcribing${'.' * widget.transcribeDotCount}';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Back button row
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('Back to Welcome'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          
          // Enhanced Patient Header Card
          _buildPatientHeader(),
          
          const SizedBox(height: 24),
          
          // Recording Controls
          if (widget.isTranscribing)
            _buildTranscribingState(transcribingText)
          else if (widget.transcript != null)
            _buildTranscriptState()
          else if (!widget.isRecording)
            _buildIdleState()
          else
            _buildRecordingState(durationText),
          
          // Previous Conversations Section
          if (!widget.isRecording && widget.previousConversations.isNotEmpty)
            _buildPreviousConversations(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
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
      child: Column(
        children: [
          // Main header row - now clickable
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Patient Avatar
                  Container(
                    width: 54,
                    height: 54,
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
                        widget.patient['name'].toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.patient['name'],
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
                          '${WelcomeUtils.calculateAge(widget.patient['dob']) ?? '-'} years old • ${widget.patient['gender']}',
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
                  
                  // Dropdown arrow
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded details
          if (_isExpanded)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 16),
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
                  if (widget.patient['dob'] != null && widget.patient['dob'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Date of Birth: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.patient['dob'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Address
                  if (widget.patient['address'] != null && widget.patient['address'].toString().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Address: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.patient['address'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
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
    );
  }

  Widget _buildTranscribingState(String transcribingText) {
    return Column(
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
    );
  }

  Widget _buildTranscriptState() {
    return const Column(
      children: [
        Text(
          '',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildIdleState() {
    // Show SOAP analysis for existing patients, recording options for new patients
    if (widget.patient['isExistingPatient'] == true) {
      return SoapAnalysisSection(
        previousConversations: widget.previousConversations,
        onStartRecording: widget.onStartRecording,
      );
    } else {
      return Column(
        children: [
          // Regular Recording Button
          GestureDetector(
            onTap: widget.onStartRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
              ),
              child: const Center(
          child: Icon(Icons.mic, color: Colors.white, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to start conversation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1976D2)),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            child: Row(
              children: [
          Expanded(child: Divider(color: Colors.grey)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey)),
              ],
            ),
          ),

          // Demo Speech Button (Box shaped, with icon, styled as requested)
          if (widget.onStartDemo != null)
            GestureDetector(
              onTap: widget.onStartDemo,
              child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1976D2).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF1976D2), size: 28),
              SizedBox(width: 12),
              Text(
                'Try Demo Speech',
                style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
                ),
              ),
            ],
          ),
              ),
            ),

          if (widget.onStartDemo != null) ...[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
          'Experience a sample medical consultation to see how the AI analyzes conversations',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.4,
          ),
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildRecordingState(String durationText) {
    return Column(
      children: [
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
              onTap: widget.isPaused ? widget.onResumeRecording : widget.onPauseRecording,
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
                    widget.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),
            GestureDetector(
              onTap: widget.onStopRecording,
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
        Text(widget.isPaused ? 'Recording paused...' : 'Recording...'),
      ],
    );
  }

  Widget _buildPreviousConversations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Previous Conversations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${widget.previousConversations.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (widget.loadingConversations)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...(widget.previousConversations.take(3).map((conversation) => 
              ConversationCard(
                conversation: conversation,
                onTap: () {
                  // TODO: Show conversation details
                },
              )).toList()),
      ],
    );
  }
}

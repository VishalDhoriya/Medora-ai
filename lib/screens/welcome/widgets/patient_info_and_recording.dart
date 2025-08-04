import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../utils/welcome_utils.dart';
import 'soap_analysis_section.dart';
import 'conversation_card.dart';

class PatientInfoAndRecording extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    String durationText = WelcomeUtils.formatRecordingDuration(recordDuration);
    String transcribingText = 'Transcribing${'.' * transcribeDotCount}';

    return Column(
      children: [
        // Enhanced Patient Header Card
        _buildPatientHeader(),
        
        const SizedBox(height: 24),
        
        // Recording Controls
        if (isTranscribing)
          _buildTranscribingState(transcribingText)
        else if (transcript != null)
          _buildTranscriptState()
        else if (!isRecording)
          _buildIdleState()
        else
          _buildRecordingState(durationText),
        
        // Previous Conversations Section
        if (!isRecording && previousConversations.isNotEmpty)
          _buildPreviousConversations(),
      ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Patient Avatar
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
                  patient['name'].toString().substring(0, 1).toUpperCase(),
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
                    patient['name'],
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
                    '${WelcomeUtils.calculateAge(patient['dob']) ?? '-'} years old • ${patient['gender']}',
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
    // Show SOAP analysis for existing patients, mic button for new patients
    if (patient['isExistingPatient'] == true) {
      return SoapAnalysisSection(
        previousConversations: previousConversations,
        onStartRecording: onStartRecording,
      );
    } else {
      return Column(
        children: [
          GestureDetector(
            onTap: onStartRecording,
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
              onTap: isPaused ? onResumeRecording : onPauseRecording,
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
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),
            GestureDetector(
              onTap: onStopRecording,
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
        Text(isPaused ? 'Recording paused...' : 'Recording...'),
      ],
    );
  }

  Widget _buildPreviousConversations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
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
                '${previousConversations.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (loadingConversations)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...(previousConversations.take(3).map((conversation) => 
              ConversationCard(
                conversation: conversation,
                onTap: () {
                  // TODO: Show conversation details
                },
              )).toList()),
        
        if (previousConversations.length > 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                // TODO: Show all conversations
              },
              child: Text(
                'View all ${previousConversations.length} conversations',
                style: const TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

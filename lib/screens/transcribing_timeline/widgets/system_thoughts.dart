import 'package:flutter/material.dart';

class SystemThoughts extends StatelessWidget {
  final bool transcribeDone;
  final bool llmDone;
  final Duration? transcribeDuration;
  final Duration? llmDuration;
  final Duration liveTranscribe;
  final Duration liveLlm;
  final String? transcript;
  final String? llmResponse;
  
  const SystemThoughts({
    super.key,
    required this.transcribeDone,
    required this.llmDone,
    required this.liveTranscribe,
    required this.liveLlm,
    this.transcribeDuration,
    this.llmDuration,
    this.transcript,
    this.llmResponse,
  });

  String buildSystemThoughtsContent() {
    if (!transcribeDone) {
      return 'Converting speech to text...';
    } else if (!llmDone) {
      return 'Analyzing medical content and generating insights...';
    } else {
      return 'All processes complete. Click to view details.';
    }
  }

  Widget buildSystemThoughtsExpandedContent() {
    return Column(
      children: [
        // Mini Timeline inside System Thoughts - show steps progressively
        Column(
          children: [
            // Always show Transcription Timeline Item
            _buildMiniTimelineItem(
              label: 'Transcription',
              icon: Icons.mic,
              duration: transcribeDone ? transcribeDuration : liveTranscribe,
              content: transcribeDone 
                  ? (transcript ?? 'No transcription available.') 
                  : 'Converting speech to text...',
              isFirst: true,
              isLast: !transcribeDone, // Last if transcription not done yet
              isCompleted: transcribeDone,
            ),
            
            // Only show LLM Analysis after transcription is done
            if (transcribeDone)
              _buildMiniTimelineItem(
                label: 'LLM Analysis',
                icon: Icons.auto_awesome,
                duration: llmDone ? llmDuration : liveLlm,
                content: llmDone 
                    ? (llmResponse ?? 'No LLM analysis available.') 
                    : 'Analyzing medical content and generating insights...',
                isFirst: false,
                isLast: !llmDone, // Last if LLM not done yet
                isCompleted: llmDone,
              ),

            // Only show SOAP Note Generation after LLM is done
            if (llmDone)
              _buildMiniTimelineItem(
                label: 'SOAP Note Generation',
                icon: Icons.description,
                duration: null, // No time display
                content: 'SOAP note generated successfully from analysis.',
                isFirst: false,
                isLast: true, // Always last step
                isCompleted: llmDone,
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
    required bool isCompleted,
  }) {
    final Color accent = isCompleted ? Color(0xFF1976D2) : Color(0xFF757575);
    final Color borderColor = isCompleted ? Color(0xFF1976D2) : Color(0xFF757575);
    final Color bgColor = isCompleted ? Color(0xFFF4F9FE) : Color(0xFFF5F5F5);

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

  @override
  Widget build(BuildContext context) {
    return buildSystemThoughtsExpandedContent();
  }
}

import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../utils/welcome_utils.dart';

class ConversationCard extends StatelessWidget {
  final CompleteConversationData conversation;
  final VoidCallback? onTap;

  const ConversationCard({
    super.key,
    required this.conversation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: conversation.llmOutput?.extractionSuccess == true
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: conversation.llmOutput?.extractionSuccess == true
                            ? Colors.green[200]!
                            : Colors.orange[200]!,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          conversation.llmOutput?.extractionSuccess == true
                              ? Icons.check_circle
                              : Icons.pending,
                          size: 14,
                          color: conversation.llmOutput?.extractionSuccess == true
                              ? Colors.green[600]
                              : Colors.orange[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          conversation.llmOutput?.extractionSuccess == true
                              ? 'Analyzed'
                              : 'Processing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: conversation.llmOutput?.extractionSuccess == true
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    WelcomeUtils.formatDate(conversation.conversation.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                conversation.conversation.title ?? 'Medical Consultation',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getPreview(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (conversation.conversation.duration != null && 
                  conversation.conversation.duration! > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      WelcomeUtils.formatDuration(conversation.conversation.duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getPreview() {
    if (conversation.transcription?.transcript != null) {
      final transcript = conversation.transcription!.transcript;
      return transcript.length > 80 ? '${transcript.substring(0, 80)}...' : transcript;
    }
    return 'No transcription available';
  }
}

import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../utils/welcome_utils.dart';

class SoapAnalysisSection extends StatelessWidget {
  final List<CompleteConversationData> previousConversations;
  final VoidCallback onStartRecording;

  const SoapAnalysisSection({
    super.key,
    required this.previousConversations,
    required this.onStartRecording,
  });

  @override
  Widget build(BuildContext context) {
    // Get the most recent conversation with LLM analysis
    CompleteConversationData? recentAnalysis;
    if (previousConversations.isNotEmpty) {
      // Find the most recent conversation with valid LLM output
      for (var conversation in previousConversations) {
        if (conversation.llmOutput?.extractionSuccess == true) {
          recentAnalysis = conversation;
          break;
        }
      }
    }

    if (recentAnalysis?.llmOutput == null || 
        recentAnalysis!.llmOutput!.extractionSuccess != true) {
      return _buildNoAnalysisAvailable();
    }

    final llmData = recentAnalysis.llmOutput!;
    final jsonData = llmData.parsedJson ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSoapHeader(),
        const SizedBox(height: 16),
        _buildSoapContent(jsonData),
        const SizedBox(height: 12),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildNoAnalysisAvailable() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
          child: Icon(
            Icons.assignment_outlined,
            color: Colors.grey[400],
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'No SOAP analysis available',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onStartRecording,
          child: const Text(
            'Start New Consultation',
            style: TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoapHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOAP Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Latest medical assessment',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoapContent(Map<String, dynamic> jsonData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Symptoms Section
            if (jsonData['Reported_Symptoms'] is List && 
                (jsonData['Reported_Symptoms'] as List).isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.sick,
                title: 'Reported Symptoms',
                content: (jsonData['Reported_Symptoms'] as List).join(', '),
                color: Colors.red,
              ),
              const SizedBox(height: 16),
            ],
            
            // History of Present Illness
            if (jsonData['HPI'] != null && jsonData['HPI'].toString().isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.history,
                title: 'History',
                content: jsonData['HPI'].toString(),
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
            ],
            
            // Primary Diagnosis
            if (jsonData['Primary_Diagnosis'] != null && 
                jsonData['Primary_Diagnosis'].toString().isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.medical_services,
                title: 'Primary Diagnosis',
                content: jsonData['Primary_Diagnosis'].toString(),
                color: Colors.green,
              ),
              const SizedBox(height: 16),
            ],
            
            // Assessment
            if (jsonData['Symptom_Assessment'] != null && 
                jsonData['Symptom_Assessment'].toString().isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.assessment,
                title: 'Assessment',
                content: jsonData['Symptom_Assessment'].toString(),
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
            ],
            
            // Recommended Tests
            if (jsonData['Diagnostic_Tests'] is List && 
                (jsonData['Diagnostic_Tests'] as List).isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.science,
                title: 'Recommended Tests',
                content: (jsonData['Diagnostic_Tests'] as List).join(', '),
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
            ],
            
            // Treatment Plan
            if (jsonData['Therapeutics'] is List && 
                (jsonData['Therapeutics'] as List).isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.medication,
                title: 'Treatment Plan',
                content: (jsonData['Therapeutics'] as List).join(', '),
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
            ],
            
            // Patient Education
            if (jsonData['Education'] is List && 
                (jsonData['Education'] as List).isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.school,
                title: 'Patient Education',
                content: (jsonData['Education'] as List).join(', '),
                color: Colors.indigo,
              ),
              const SizedBox(height: 16),
            ],
            
            // Follow-up
            if (jsonData['FollowUp'] != null && 
                jsonData['FollowUp'].toString().isNotEmpty) ...[
              _buildSoapSection(
                icon: Icons.event,
                title: 'Follow-up',
                content: jsonData['FollowUp'].toString(),
                color: Colors.brown,
              ),
            ],
            
            // Show message if no data available
            if (WelcomeUtils.shouldShowNoDataMessage(jsonData)) ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[400],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No detailed analysis data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The conversation was recorded but detailed medical analysis is not available.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSoapSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
    );
  }
}

/// Utility functions for the Welcome screen
class WelcomeUtils {
  /// Calculate age from date of birth string in YYYY-MM-DD format
  static int? calculateAge(String dob) {
    try {
      final parts = dob.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || 
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  /// Format date string to relative format (Today, Yesterday, etc.)
  static String formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Format duration from seconds to readable format
  static String formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  /// Format recording duration to MM:SS format
  static String formatRecordingDuration(int seconds) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(seconds ~/ 60)}:${twoDigits(seconds % 60)}';
  }

  /// Check if SOAP analysis data has meaningful content
  static bool shouldShowNoDataMessage(Map<String, dynamic> jsonData) {
    final hasSymptoms = jsonData['Reported_Symptoms'] is List && 
        (jsonData['Reported_Symptoms'] as List).isNotEmpty;
    final hasHPI = jsonData['HPI'] != null && 
        jsonData['HPI'].toString().isNotEmpty;
    final hasDiagnosis = jsonData['Primary_Diagnosis'] != null && 
        jsonData['Primary_Diagnosis'].toString().isNotEmpty;
    final hasAssessment = jsonData['Symptom_Assessment'] != null && 
        jsonData['Symptom_Assessment'].toString().isNotEmpty;
    
    return !hasSymptoms && !hasHPI && !hasDiagnosis && !hasAssessment;
  }
}

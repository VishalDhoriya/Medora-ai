import 'dart:convert';
import 'package:flutter/material.dart';

/// Data class for timeline steps
class StepData {
  final String label;
  final IconData icon;
  final bool completed;
  final Duration? duration;
  final String? content;
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget? customExpandedContent;
  
  StepData({
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

/// Utility functions for timeline operations
class TimelineUtils {
  /// Calculate age from date of birth string
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

  /// Parse JSON from LLM response
  static Map<String, dynamic>? parseJson(String text) {
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
}

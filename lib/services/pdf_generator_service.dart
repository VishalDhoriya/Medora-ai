import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class PdfGeneratorService {
  static Future<Uint8List> generateMedicalReport({
    required Map<String, dynamic> soapData,
    required Map<String, dynamic> patientData,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24), // Reduced from 32
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(boldFont, font),
            pw.SizedBox(height: 8), // Reduced from 12
            
            // Patient Information
            _buildPatientInfo(patientData, boldFont, font),
            pw.SizedBox(height: 8), // Reduced from 12
            
            // Patient-Friendly Medical Report
            _buildPatientFriendlyReport(soapData, boldFont, font),
            pw.SizedBox(height: 8), // Reduced from 12
            
            // Footer
            _buildFooter(font),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.Font boldFont, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MEDICAL REPORT',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: PdfColors.grey800,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Clinical Assessment & Treatment Plan',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Date: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Time: ${DateTime.now().toString().substring(11, 16)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8), // Reduced from 16
        pw.Container(
          width: double.infinity,
          height: 1,
          color: PdfColors.grey400,
        ),
      ],
    );
  }

  static pw.Widget _buildPatientInfo(
    Map<String, dynamic> patientData,
    pw.Font boldFont,
    pw.Font font,
  ) {
    // Calculate age
    String age = 'Unknown';
    if (patientData['dob'] != null) {
      final dob = DateTime.tryParse(patientData['dob']);
      if (dob != null) {
        final ageInYears = DateTime.now().difference(dob).inDays ~/ 365;
        age = '$ageInYears years';
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT INFORMATION',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 12,
            color: PdfColors.grey700,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 8), // Reduced from 12
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8), // Reduced from 12
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildCleanInfoRow('Name', patientData['name'] ?? 'N/A', boldFont, font),
                    pw.SizedBox(height: 6), // Reduced from 8
                    _buildCleanInfoRow('Age', age, boldFont, font),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildCleanInfoRow('Gender', patientData['gender'] ?? 'N/A', boldFont, font),
                    pw.SizedBox(height: 6), // Reduced from 8
                    _buildCleanInfoRow('DOB', patientData['dob'] ?? 'N/A', boldFont, font),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.grey300,
        ),
        pw.SizedBox(height: 8), // Reduced from 16
      ],
    );
  }

  static pw.Widget _buildCleanInfoRow(String label, String value, pw.Font boldFont, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 11,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPatientFriendlyReport(
    Map<String, dynamic> soapData,
    pw.Font boldFont,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Report title with clean styling
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
          ),
          child: pw.Text(
            'MEDICAL REPORT',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 18,
              color: PdfColors.grey800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.SizedBox(height: 12), // Reduced from 16
        
        // Symptoms & Concerns
        _buildCleanSection('SYMPTOMS & CONCERNS', 
          _combinePatientSymptoms(soapData), boldFont, font),
        
        // Physical Examination
        if (soapData['Vitals_Exam'] != null && soapData['Vitals_Exam'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 10), // Reduced from 12
          _buildCleanSection('PHYSICAL EXAMINATION', 
            _formatForPatients(soapData['Vitals_Exam']), boldFont, font),
        ],
        
        // Diagnosis
        pw.SizedBox(height: 10), // Reduced from 12
        _buildCleanSection('DIAGNOSIS & ASSESSMENT', 
          _formatDiagnosisForPatients(soapData), boldFont, font),
        
        // Treatment Plan
        pw.SizedBox(height: 10), // Reduced from 12
        _buildCleanSection('TREATMENT PLAN', 
          _formatTreatmentForPatients(soapData), boldFont, font),
        
        // Medications
        if (_hasMedications(soapData)) ...[
          pw.SizedBox(height: 10), // Reduced from 12
          _buildMedicationsSection(soapData, boldFont, font),
        ],
        
        // Follow-up Instructions
        if (soapData['FollowUp'] != null && soapData['FollowUp'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 10), // Reduced from 12
          _buildCleanSection('FOLLOW-UP INSTRUCTIONS', 
            _formatForPatients(soapData['FollowUp']), boldFont, font),
        ],
        
        // Summary (if available)
        if (soapData['Patient_Summary'] != null && soapData['Patient_Summary'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 16), // Reduced from 24
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12), // Reduced from 16
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SUMMARY',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: PdfColors.grey700,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 6), // Reduced from 8
                pw.Text(
                  soapData['Patient_Summary'].toString(),
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.grey800,
                    lineSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Helper methods for clean, professional formatting
  static pw.Widget _buildCleanSection(
    String title,
    String content,
    pw.Font boldFont,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 12,
            color: PdfColors.grey700,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6), // Reduced from 8
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Reduced from 12
          child: pw.Text(
            content.isNotEmpty ? content : 'Not specified',
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: content.isNotEmpty ? PdfColors.grey800 : PdfColors.grey500,
              lineSpacing: 1.2, // Reduced from 1.4
            ),
          ),
        ),
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.grey300,
        ),
      ],
    );
  }

  static pw.Widget _buildMedicationsSection(
    Map<String, dynamic> soapData,
    pw.Font boldFont,
    pw.Font font,
  ) {
    String medsText = _formatForPatients(soapData['Meds_Allergies']);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MEDICATIONS & ALLERGIES',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 12,
            color: PdfColors.grey700,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6), // Reduced from 8
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10), // Reduced from 12
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                medsText.isNotEmpty ? medsText : 'No medications or allergies specified',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  color: medsText.isNotEmpty ? PdfColors.grey800 : PdfColors.grey500,
                  lineSpacing: 1.2, // Reduced from 1.4
                ),
              ),
              if (medsText.isNotEmpty) ...[
                pw.SizedBox(height: 6), // Reduced from 8
                pw.Text(
                  'Important: Always inform healthcare providers about medications and allergies',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.grey300,
        ),
      ],
    );
  }

  static String _combinePatientSymptoms(Map<String, dynamic> soapData) {
    List<String> symptoms = [];
    
    // Add reported symptoms
    if (soapData['Reported_Symptoms'] != null) {
      String reported = _formatForPatients(soapData['Reported_Symptoms']);
      if (reported.isNotEmpty) symptoms.add(reported);
    }
    
    // Add history of present illness
    if (soapData['HPI'] != null) {
      String hpi = _formatForPatients(soapData['HPI']);
      if (hpi.isNotEmpty) symptoms.add(hpi);
    }
    
    return symptoms.join('\n\n');
  }

  static String _formatDiagnosisForPatients(Map<String, dynamic> soapData) {
    List<String> diagnosis = [];
    
    // Primary diagnosis
    if (soapData['Primary_Diagnosis'] != null) {
      String primary = _formatForPatients(soapData['Primary_Diagnosis']);
      if (primary.isNotEmpty) {
        diagnosis.add('Primary: $primary');
      }
    }
    
    // Clinical assessment
    if (soapData['Symptom_Assessment'] != null) {
      String assessment = _formatForPatients(soapData['Symptom_Assessment']);
      if (assessment.isNotEmpty) {
        diagnosis.add('Assessment: $assessment');
      }
    }
    
    // Other possible conditions
    if (soapData['Differentials'] != null) {
      String differentials = _formatForPatients(soapData['Differentials']);
      if (differentials.isNotEmpty) {
        diagnosis.add('Other possibilities to consider: $differentials');
      }
    }
    
    return diagnosis.join('\n\n');
  }

  static String _formatTreatmentForPatients(Map<String, dynamic> soapData) {
    List<String> treatment = [];
    
    // Treatment plan
    if (soapData['Therapeutics'] != null) {
      String therapeutics = _formatForPatients(soapData['Therapeutics']);
      if (therapeutics.isNotEmpty) {
        treatment.add('Treatment: $therapeutics');
      }
    }
    
    // Patient education
    if (soapData['Education'] != null) {
      String education = _formatForPatients(soapData['Education']);
      if (education.isNotEmpty) {
        treatment.add('Important information: $education');
      }
    }
    
    // Diagnostic tests
    if (soapData['Diagnostic_Tests'] != null) {
      String tests = _formatForPatients(soapData['Diagnostic_Tests']);
      if (tests.isNotEmpty) {
        treatment.add('Recommended tests: $tests');
      }
    }
    
    return treatment.join('\n\n');
  }

  static String _formatForPatients(dynamic value) {
    if (value == null) return '';
    
    if (value is List && value.isNotEmpty) {
      return value.join(', ');
    } else if (value is String && value.isNotEmpty) {
      return value;
    }
    
    return '';
  }

  static bool _hasMedications(Map<String, dynamic> soapData) {
    return soapData['Meds_Allergies'] != null && 
           soapData['Meds_Allergies'].toString().isNotEmpty;
  }

  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 16), // Reduced from 24
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.grey400,
        ),
        pw.SizedBox(height: 12), // Reduced from 16
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This report is electronically generated.',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
            pw.Text(
              'Please consult your healthcare provider.',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<File> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  static Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    try {
      // Try to share using the printing package
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      print('Printing.sharePdf failed: $e');
      // Fallback: save to file and show location
      try {
        final file = await savePdfToFile(pdfBytes, fileName);
        print('PDF saved to: ${file.path}');
        // You could show a toast or dialog here telling the user where the file was saved
      } catch (saveError) {
        print('Failed to save PDF: $saveError');
        rethrow;
      }
    }
  }

  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Preview PDF in the built-in viewer
  static Future<bool> previewMedicalReport({
    required Map<String, dynamic> soapData,
    required Map<String, dynamic> patientData,
  }) async {
    try {
      // Generate the PDF
      final pdfBytes = await generateMedicalReport(
        soapData: soapData,
        patientData: patientData,
      );

      // Show PDF preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      
      return true;
    } catch (e) {
      print('Error previewing PDF: $e');
      return false;
    }
  }

  /// Convenience method that generates a medical report and saves it
  static Future<bool> generateAndSaveMedicalReport({
    required Map<String, dynamic> soapData,
    required Map<String, dynamic> patientData,
  }) async {
    try {
      // Generate the PDF
      final pdfBytes = await generateMedicalReport(
        soapData: soapData,
        patientData: patientData,
      );

      // Create filename with patient name and timestamp
      final patientName = patientData['name'] ?? 'Patient';
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'Medical_Report_${patientName.replaceAll(' ', '_')}_$timestamp.pdf';

      // Save the PDF to file
      final file = await savePdfToFile(pdfBytes, fileName);
      print('PDF saved successfully to: ${file.path}');
      
      return true;
    } catch (e) {
      print('Error generating and saving PDF: $e');
      return false;
    }
  }

  /// Convenience method that generates a medical report and shares it
  static Future<bool> generateAndShareMedicalReport({
    required Map<String, dynamic> soapData,
    required Map<String, dynamic> patientData,
  }) async {
    try {
      // Generate the PDF
      final pdfBytes = await generateMedicalReport(
        soapData: soapData,
        patientData: patientData,
      );

      // Create filename with patient name and timestamp
      final patientName = patientData['name'] ?? 'Patient';
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'Medical_Report_${patientName.replaceAll(' ', '_')}_$timestamp.pdf';

      // Try to share the PDF
      await sharePdf(pdfBytes, fileName);
      
      return true;
    } catch (e) {
      print('Error generating and sharing PDF: $e');
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import '../../../core/services/pdf_generator_service.dart';

class EditableSoapSummary extends StatefulWidget {
  final Map<String, dynamic> json;
  final ScrollController soapScrollController;
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? patient;
  
  const EditableSoapSummary({
    super.key,
    required this.json,
    required this.soapScrollController,
    required this.onSave,
    this.patient,
  });

  @override
  State<EditableSoapSummary> createState() => _EditableSoapSummaryState();
}

class _EditableSoapSummaryState extends State<EditableSoapSummary> {
  late Map<String, dynamic> _editableData;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<TextEditingController>> _listControllers = {};
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _editableData = Map<String, dynamic>.from(widget.json);
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize text controllers for simple fields
    _controllers['HPI'] = TextEditingController(text: _editableData['HPI']?.toString() ?? '');
    _controllers['Vitals_Exam'] = TextEditingController(text: _editableData['Vitals_Exam']?.toString() ?? '');
    _controllers['Symptom_Assessment'] = TextEditingController(text: _editableData['Symptom_Assessment']?.toString() ?? '');
    _controllers['Primary_Diagnosis'] = TextEditingController(text: _editableData['Primary_Diagnosis']?.toString() ?? '');
    _controllers['FollowUp'] = TextEditingController(text: _editableData['FollowUp']?.toString() ?? '');

    // Initialize list controllers for list fields
    _initializeListControllers('Reported_Symptoms', _editableData['Reported_Symptoms']);
    _initializeListControllers('Meds_Allergies', _editableData['Meds_Allergies']);
    _initializeListControllers('Differentials', _editableData['Differentials']);
    _initializeListControllers('Diagnostic_Tests', _editableData['Diagnostic_Tests']);
    _initializeListControllers('Therapeutics', _editableData['Therapeutics']);
    _initializeListControllers('Education', _editableData['Education']);
  }

  void _initializeListControllers(String key, dynamic value) {
    _listControllers[key] = [];
    if (value is List && value.isNotEmpty) {
      for (var item in value) {
        _listControllers[key]!.add(TextEditingController(text: item.toString()));
      }
    } else {
      // Add at least one empty controller
      _listControllers[key]!.add(TextEditingController());
    }
  }

  void _addListItem(String key) {
    setState(() {
      _listControllers[key]!.add(TextEditingController());
    });
  }

  void _removeListItem(String key, int index) {
    if (_listControllers[key]!.length > 1) {
      setState(() {
        _listControllers[key]![index].dispose();
        _listControllers[key]!.removeAt(index);
      });
    }
  }

  void _saveChanges() {
    // Update simple fields
    _editableData['HPI'] = _controllers['HPI']!.text.trim().isEmpty ? null : _controllers['HPI']!.text.trim();
    _editableData['Vitals_Exam'] = _controllers['Vitals_Exam']!.text.trim().isEmpty ? null : _controllers['Vitals_Exam']!.text.trim();
    _editableData['Symptom_Assessment'] = _controllers['Symptom_Assessment']!.text.trim().isEmpty ? null : _controllers['Symptom_Assessment']!.text.trim();
    _editableData['Primary_Diagnosis'] = _controllers['Primary_Diagnosis']!.text.trim().isEmpty ? null : _controllers['Primary_Diagnosis']!.text.trim();
    _editableData['FollowUp'] = _controllers['FollowUp']!.text.trim().isEmpty ? null : _controllers['FollowUp']!.text.trim();

    // Update list fields
    _updateListField('Reported_Symptoms');
    _updateListField('Meds_Allergies');
    _updateListField('Differentials');
    _updateListField('Diagnostic_Tests');
    _updateListField('Therapeutics');
    _updateListField('Education');

    setState(() {
      _isEditing = false;
    });

    widget.onSave(_editableData);
  }

  void _generateSummary() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Extract patient information
      final patient = widget.patient ?? {};

      // Prepare SOAP data from current form values
      final soapData = {
        'HPI': _controllers['HPI']?.text ?? '',
        'Reported_Symptoms': _listControllers['Reported_Symptoms']?.map((c) => c.text).toList() ?? [],
        'Vitals_Exam': _controllers['Vitals_Exam']?.text ?? '',
        'Meds_Allergies': _listControllers['Meds_Allergies']?.map((c) => c.text).toList() ?? [],
        'Symptom_Assessment': _controllers['Symptom_Assessment']?.text ?? '',
        'Differentials': _listControllers['Differentials']?.map((c) => c.text).toList() ?? [],
        'Primary_Diagnosis': _controllers['Primary_Diagnosis']?.text ?? '',
        'Diagnostic_Tests': _listControllers['Diagnostic_Tests']?.map((c) => c.text).toList() ?? [],
        'Therapeutics': _listControllers['Therapeutics']?.map((c) => c.text).toList() ?? [],
        'Education': _listControllers['Education']?.map((c) => c.text).toList() ?? [],
        'FollowUp': _controllers['FollowUp']?.text ?? '',
      };

      // Generate and share PDF (with fallback to save)
      bool success = false;
      try {
        success = await PdfGeneratorService.generateAndShareMedicalReport(
          soapData: soapData,
          patientData: patient,
        );
      } catch (e) {
        print('Share failed, trying to save: $e');
        // Fallback to just saving the PDF
        success = await PdfGeneratorService.generateAndSaveMedicalReport(
          soapData: soapData,
          patientData: patient,
        );
      }

      // Hide loading indicator
      Navigator.of(context).pop();

      if (!success) {
        // Show error message only if sharing failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share PDF report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // No success message - sharing dialog will handle user feedback
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _previewReport() async {
    // Validate patient data
    if (widget.patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient information is required for PDF preview.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current data from controllers
      final Map<String, dynamic> patient = Map<String, dynamic>.from(widget.patient!);
      final Map<String, dynamic> soapData = {
        'Reported_Symptoms': _listControllers['Reported_Symptoms']?.map((c) => c.text).toList() ?? [],
        'HPI': _controllers['HPI']?.text ?? '',
        'Vitals_Exam': _controllers['Vitals_Exam']?.text ?? '',
        'Meds_Allergies': _listControllers['Meds_Allergies']?.map((c) => c.text).toList() ?? [],
        'Symptom_Assessment': _controllers['Symptom_Assessment']?.text ?? '',
        'Differentials': _listControllers['Differentials']?.map((c) => c.text).toList() ?? [],
        'Primary_Diagnosis': _controllers['Primary_Diagnosis']?.text ?? '',
        'Diagnostic_Tests': _listControllers['Diagnostic_Tests']?.map((c) => c.text).toList() ?? [],
        'Therapeutics': _listControllers['Therapeutics']?.map((c) => c.text).toList() ?? [],
        'Education': _listControllers['Education']?.map((c) => c.text).toList() ?? [],
        'FollowUp': _controllers['FollowUp']?.text ?? '',
      };

      // Preview the PDF
      final success = await PdfGeneratorService.previewMedicalReport(
        soapData: soapData,
        patientData: patient,
      );

      // Hide loading indicator
      Navigator.of(context).pop();

      if (!success) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to preview PDF report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error previewing PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateListField(String key) {
    List<String> items = _listControllers[key]!
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    _editableData[key] = items.isEmpty ? [] : items;
  }

  void _disposeControllers() {
    _controllers.values.forEach((controller) => controller.dispose());
    _listControllers.values.forEach((controllers) {
      controllers.forEach((controller) => controller.dispose());
    });
    _controllers.clear();
    _listControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editableData['extraction_success'] == false) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SOAP Note', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Edit sections below and save your changes.', 
                   style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final expanded = List<bool>.filled(4, true);
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  return Container(
                    width: double.infinity,
                    child: Scrollbar(
                      controller: widget.soapScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: widget.soapScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Subjective
                            _buildSoapSection(
                              title: 'Subjective',
                              expanded: expanded,
                              index: 0,
                              setLocalState: setLocalState,
                              children: [
                                _buildListField('Reported Symptoms', 'Reported_Symptoms'),
                                _buildTextField('HPI', 'HPI'),
                                _buildListField('Meds & Allergies', 'Meds_Allergies'),
                              ],
                            ),
                            
                            // Objective
                            _buildSoapSection(
                              title: 'Objective',
                              expanded: expanded,
                              index: 1,
                              setLocalState: setLocalState,
                              children: [
                                _buildTextField('Vitals & Exam', 'Vitals_Exam'),
                              ],
                            ),
                            
                            // Assessment
                            _buildSoapSection(
                              title: 'Assessment',
                              expanded: expanded,
                              index: 2,
                              setLocalState: setLocalState,
                              children: [
                                _buildTextField('Symptom Assessment', 'Symptom_Assessment'),
                                _buildTextField('Primary Diagnosis', 'Primary_Diagnosis'),
                                _buildListField('Differentials', 'Differentials'),
                              ],
                            ),
                            
                            // Plan
                            _buildSoapSection(
                              title: 'Plan',
                              expanded: expanded,
                              index: 3,
                              setLocalState: setLocalState,
                              children: [
                                _buildListField('Diagnostic Tests', 'Diagnostic_Tests'),
                                _buildListField('Therapeutics', 'Therapeutics'),
                                _buildListField('Education', 'Education'),
                                _buildTextField('Follow Up', 'FollowUp'),
                              ],
                            ),
                            
                            // Extra padding at bottom for scroll
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Bottom buttons section
          const SizedBox(height: 16),
          Column(
            children: [
              // Save/Edit button at the top
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isEditing ? _saveChanges : () => setState(() => _isEditing = true),
                  icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                  label: Text(_isEditing ? 'Save Changes' : 'Edit SOAP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Generate and Share buttons in a row
              Row(
                children: [
                  // Generate Report button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _previewReport,
                      icon: const Icon(Icons.auto_awesome_mosaic, size: 18),
                      label: const Text('Generate Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                        foregroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: const Color(0xFF1976D2).withOpacity(0.3)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share Report button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generateSummary,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoapSection({
    required String title,
    required List<bool> expanded,
    required int index,
    required StateSetter setLocalState,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F9FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.18), width: 1.2),
        ),
        child: ExpansionPanelList(
          elevation: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          expansionCallback: (int panelIndex, bool isExpanded) {
            setLocalState(() {
              expanded[index] = !expanded[index];
            });
          },
          children: [
            ExpansionPanel(
              canTapOnHeader: true,
              isExpanded: expanded[index],
              backgroundColor: Colors.transparent,
              headerBuilder: (context, isExpanded) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key) {
    if (!_isEditing) {
      // Display mode - read-only
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _editableData[key]?.toString().isEmpty == true || _editableData[key] == null
                    ? 'None'
                    : _editableData[key].toString(),
                style: TextStyle(
                  fontSize: 16,
                  color: _editableData[key]?.toString().isEmpty == true || _editableData[key] == null
                      ? Colors.grey
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Edit mode - editable
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _controllers[key],
              maxLines: null,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter $label',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListField(String label, String key) {
    if (!_isEditing) {
      // Display mode - show as read-only chips
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _editableData[key] == null || (_editableData[key] is List && _editableData[key].isEmpty)
                  ? const Text('None', style: TextStyle(color: Colors.grey, fontSize: 14))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_editableData[key] as List).map<Widget>((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF1976D2).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item.toString(),
                            style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      );
    }

    // Edit mode - show as editable chips
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$label:',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _addListItem(key),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _listControllers[key]!.isEmpty
                ? const Text(
                    'No items yet. Click Add to create new entries.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _listControllers[key]!.asMap().entries.map((entry) {
                      int index = entry.key;
                      TextEditingController controller = entry.value;
                      
                      // Show text field for new/empty items, chips for existing items
                      if (controller.text.trim().isEmpty) {
                        return IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 120, maxWidth: 300),
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: 'Enter ${label.toLowerCase()}',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF1976D2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  setState(() {
                                    // Force rebuild to show as chip
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      }
                      
                      // Show as editable chip for existing items - adaptable to content
                      return IntrinsicWidth(
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 60),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF1976D2).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: IntrinsicWidth(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF1976D2),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        // Trigger rebuild to adjust chip size
                                      });
                                    },
                                  ),
                                ),
                              ),
                              if (_listControllers[key]!.length > 1)
                                GestureDetector(
                                  onTap: () => _removeListItem(key, index),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

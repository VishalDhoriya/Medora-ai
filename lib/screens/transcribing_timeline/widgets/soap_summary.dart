import 'package:flutter/material.dart';

class SoapSummary extends StatelessWidget {
  final Map<String, dynamic> json;
  final ScrollController soapScrollController;
  
  const SoapSummary({
    super.key,
    required this.json,
    required this.soapScrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (json['extraction_success'] == false) {
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
    
    // Flat format: fields are at the top level
    final data = json;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOAP Note', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap any section to expand/collapse', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final expanded = List<bool>.filled(4, true);
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  return SizedBox(
                    width: double.infinity,
                    child: Scrollbar(
                      controller: soapScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: soapScrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // Subjective
                            _buildSoapSection(
                              title: 'Subjective',
                              expanded: expanded,
                              index: 0,
                              setLocalState: setLocalState,
                              children: [
                                _listField('Reported Symptoms', data['Reported_Symptoms']),
                                _field('HPI', data['HPI']),
                                _listField('Meds & Allergies', data['Meds_Allergies']),
                              ],
                            ),
                            
                            // Objective
                            _buildSoapSection(
                              title: 'Objective',
                              expanded: expanded,
                              index: 1,
                              setLocalState: setLocalState,
                              children: [
                                _field('Vitals & Exam', data['Vitals_Exam']),
                              ],
                            ),
                            
                            // Assessment
                            _buildSoapSection(
                              title: 'Assessment',
                              expanded: expanded,
                              index: 2,
                              setLocalState: setLocalState,
                              children: [
                                _field('Symptom Assessment', data['Symptom_Assessment']),
                                _field('Primary Diagnosis', data['Primary_Diagnosis']),
                                _listField('Differentials', data['Differentials']),
                              ],
                            ),
                            
                            // Plan
                            _buildSoapSection(
                              title: 'Plan',
                              expanded: expanded,
                              index: 3,
                              setLocalState: setLocalState,
                              children: [
                                _listField('Diagnostic Tests', data['Diagnostic_Tests']),
                                _listField('Therapeutics', data['Therapeutics']),
                                _listField('Education', data['Education']),
                                _field('Follow Up', data['FollowUp']),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
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

  Widget _field(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RichText(
            text: TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: (value == null || (value is String && value.trim().isEmpty)) ? 'None' : value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: (value == null || (value is String && value.trim().isEmpty)) ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          );
        },
      ),
    );
  }

  Widget _listField(String label, dynamic value) {
    if (value == null || (value is List && value.isEmpty)) {
      // Use the same style as non-empty, but 'None' in grey
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RichText(
              text: TextSpan(
                text: '$label: ',
                style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: 'None',
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.grey),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            );
          },
        ),
      );
    }
    if (value is List) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ...value.map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 7, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 16), softWrap: true, overflow: TextOverflow.ellipsis, maxLines: 3)),
                    ],
                  ),
                )),
          ],
        ),
      );
    }
    // fallback for non-list
    return _field(label, value);
  }
}

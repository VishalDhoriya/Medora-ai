import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import 'patient_card.dart';

class WelcomeMessage extends StatelessWidget {
  final List<PatientData> previousPatients;
  final bool loadingPatients;
  final Function(PatientData) onSelectPatient;

  const WelcomeMessage({
    super.key,
    required this.previousPatients,
    required this.loadingPatients,
    required this.onSelectPatient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Previous Patients Section
        if (previousPatients.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Patients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  '${previousPatients.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (loadingPatients)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...(previousPatients.take(5).map((patient) => 
                PatientCard(
                  patient: patient,
                  onTap: () => onSelectPatient(patient),
                )).toList()),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey[300]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey[300]),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        
        // Empty state for no patients
        if (previousPatients.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No patients yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first patient using the + button',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

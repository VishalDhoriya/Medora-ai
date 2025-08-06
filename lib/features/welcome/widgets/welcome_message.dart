import 'package:flutter/material.dart';
import '../../../../core/services/database_service.dart';
import 'patient_card.dart';

class WelcomeMessage extends StatelessWidget {
  final List<PatientData> previousPatients;
  final bool loadingPatients;
  final Function(PatientData) onSelectPatient;
  final VoidCallback onAddNewPatient;
  final String? userName;

  const WelcomeMessage({
    super.key,
    required this.previousPatients,
    required this.loadingPatients,
    required this.onSelectPatient,
    required this.onAddNewPatient,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header section - always visible
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        userName != null && userName!.isNotEmpty 
                            ? "Welcome, $userName!" 
                            : "Welcome Back!",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Select a patient to continue or add a new patient",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Scrollable patient list
        Expanded(
          child: loadingPatients
              ? const Center(child: CircularProgressIndicator())
              : previousPatients.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No patients yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Add your first patient to get started",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: previousPatients.length,
                      itemBuilder: (context, index) {
                        final patient = previousPatients[index];
                        return PatientCard(
                          patient: patient,
                          onTap: () => onSelectPatient(patient),
                        );
                      },
                    ),
        ),
        
        // Bottom section - always visible (OR divider and Add New Patient button)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Divider
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.3),
              ),
              
              const SizedBox(height: 24),
              
              // Add New Patient button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAddNewPatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Add New Patient",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

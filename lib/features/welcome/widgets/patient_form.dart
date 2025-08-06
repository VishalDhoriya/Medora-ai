import 'package:flutter/material.dart';
import '../../../../core/services/database_service.dart';

class PatientForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onPatientCreated;
  final VoidCallback onCancel;

  const PatientForm({
    super.key,
    required this.onPatientCreated,
    required this.onCancel,
  });

  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final addressController = TextEditingController();
  String selectedGender = 'Male';

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const Text(
            'Patient Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Name Field
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          // DOB Field
          TextFormField(
            controller: dobController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.cake),
              hintText: 'YYYY-MM-DD',
            ),
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                dobController.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Gender Field
          DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            items: ['Male', 'Female', 'Other'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedGender = newValue!;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Address Field
          TextFormField(
            controller: addressController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && 
                    dobController.text.isNotEmpty) {
                  // Create patient data object
                  final patient = PatientData(
                    name: nameController.text,
                    dob: dobController.text,
                    gender: selectedGender,
                    address: addressController.text,
                  );
                  
                  // Save patient to database
                  final patientId = await DatabaseService.insertPatient(patient);
                  
                  // Return patient data
                  widget.onPatientCreated({
                    'id': patientId,
                    'name': nameController.text,
                    'dob': dobController.text,
                    'gender': selectedGender,
                    'address': addressController.text,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 54),
                maximumSize: const Size(220, 54),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save and Proceed',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Cancel Button
          TextButton(
            onPressed: widget.onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

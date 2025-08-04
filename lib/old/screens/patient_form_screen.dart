import 'package:flutter/material.dart';

class PatientFormScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> patient) onPatientSaved;
  const PatientFormScreen({super.key, required this.onPatientSaved});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _age;
  String? _gender;
  String? _address;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Patient')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                onSaved: (v) => _name = v?.trim(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter age' : null,
                      onSaved: (v) => _age = v?.trim(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 18, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      validator: (v) => v == null ? 'Select gender' : null,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18),
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter address' : null,
                onSaved: (v) => _address = v?.trim(),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      widget.onPatientSaved({
                        'name': _name,
                        'age': _age,
                        'gender': _gender,
                        'address': _address,
                      });
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save Patient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/phone_number.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final DbHelper _db = DbHelper();
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add phone numbers manually',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (Optional)',
                  hintText: 'Enter name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addNumber,
                icon: const Icon(Icons.add),
                label: const Text('Add Number'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNumber() async {
    if (_formKey.currentState!.validate()) {
      final number = PhoneNumber(
        number: _numberController.text.trim(),
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      );

      await _db.insertNumber(number);
      
      _numberController.clear();
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number added successfully')),
        );
      }
    }
  }
}

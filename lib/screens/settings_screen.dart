import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DbHelper _db = DbHelper();
  AppSettings _settings = const AppSettings();
  final _delayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _db.fetchSettings();
    setState(() {
      _settings = settings;
      _delayController.text = settings.callDelaySeconds.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Call Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _delayController,
                      decoration: const InputDecoration(
                        labelText: 'Call Delay (seconds)',
                        hintText: 'Time to wait between calls',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theme Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: _settings.darkMode,
                      onChanged: (value) async {
                        final newSettings = _settings.copyWith(darkMode: value);
                        await _db.saveSettings(newSettings);
                        setState(() {
                          _settings = newSettings;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final delay = int.tryParse(_delayController.text);
    if (delay != null && delay > 0) {
      final newSettings = _settings.copyWith(callDelaySeconds: delay);
      await _db.saveSettings(newSettings);
      setState(() {
        _settings = newSettings;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid delay time')),
        );
      }
    }
  }
}

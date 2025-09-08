import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import 'call_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'import_screen.dart';
import 'manual_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int pending = 0;
  int completed = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final db = DbHelper();
    final p = await db.pendingCount();
    final c = await db.completedCount();
    if (!mounted) return;
    setState(() {
      pending = p;
      completed = c;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DialDesk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending: $pending', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Completed: $completed', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadCounts,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CallScreen()),
                );
              },
              icon: const Icon(Icons.phone_forwarded),
              label: const Text('Start Calling'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImportScreen()),
                ).then((_) => _loadCounts());
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Import Data'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
                ).then((_) => _loadCounts());
              },
              icon: const Icon(Icons.edit),
              label: const Text('Manual Entry'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('Reports'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

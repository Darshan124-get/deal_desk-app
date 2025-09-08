import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db_helper.dart';
import '../models/call_log.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DbHelper _db = DbHelper();
  List<CallLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _db.fetchLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Reports'),
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.share),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    'No call logs found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(log.status),
                          child: Icon(
                            _getStatusIcon(log.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(log.phoneNumber),
                        subtitle: Text(
                          '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} '
                          '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: Text(
                          log.status.name.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(log.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.completed:
        return Colors.green;
      case CallStatus.notAnswered:
        return Colors.red;
      case CallStatus.skipped:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(CallStatus status) {
    switch (status) {
      case CallStatus.completed:
        return Icons.check;
      case CallStatus.notAnswered:
        return Icons.call_missed;
      case CallStatus.skipped:
        return Icons.skip_next;
    }
  }

  Future<void> _exportReport() async {
    if (_logs.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Call Report - ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('Phone Number,Status,Date,Time');
    
    for (final log in _logs) {
      buffer.writeln(
        '${log.phoneNumber},${log.status.name},'
        '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year},'
        '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
      );
    }

    await Share.share(
      buffer.toString(),
      subject: 'DialDesk Call Report',
    );
  }
}

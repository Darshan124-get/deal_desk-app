import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;
import 'dart:io';

import '../data/db_helper.dart';
import '../models/call_log.dart';
import '../models/call_review.dart';
import '../models/phone_number.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final DbHelper _db = DbHelper();
  List<CallLog> _logs = [];
  List<CallReview> _reviews = [];
  List<PhoneNumber> _phoneNumbers = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes active
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Add delay to ensure database is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      final logs = await _db.fetchLogs();
      final reviews = await _db.fetchCallReviews();
      final phoneNumbers = await _db.fetchAllNumbers();
      
      if (mounted) {
        setState(() {
          _logs = logs;
          _reviews = reviews;
          _phoneNumbers = phoneNumbers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = [];
          _reviews = [];
          _phoneNumbers = [];
          _isLoading = false;
        });
        if (kDebugMode) {
          print('Error loading reports data: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.rate_review), text: 'Call Notes'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCallNotesTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildCallNotesTab() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No call reviews found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Complete calls and add reviews to see them here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
          final phoneNumber = _phoneNumbers.firstWhere(
            (p) => p.id == review.phoneId,
            orElse: () => PhoneNumber(number: review.phoneNumber),
          );
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getReviewTypeColor(review.reviewType),
                child: Icon(
                  _getReviewTypeIcon(review.reviewType),
                  color: Colors.white,
                ),
              ),
              title: Text(review.phoneNumber),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phoneNumber.name != null && phoneNumber.name!.isNotEmpty)
                    Text(
                      phoneNumber.name!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  Text(
                    '${review.timestamp.day}/${review.timestamp.month}/${review.timestamp.year} '
                    '${review.timestamp.hour}:${review.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (review.customNote != null && review.customNote!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          review.customNote!,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getReviewTypeColor(review.reviewType).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  review.reviewType.toUpperCase(),
                  style: TextStyle(
                    color: _getReviewTypeColor(review.reviewType),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No call history found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Make calls to see history here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          final phoneNumber = _phoneNumbers.firstWhere(
            (p) => p.id == log.phoneId,
            orElse: () => PhoneNumber(number: log.phoneNumber),
          );
          
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phoneNumber.name != null && phoneNumber.name!.isNotEmpty)
                    Text(
                      phoneNumber.name!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  Text(
                    '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} '
                    '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(log.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.status.name.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(log.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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

  Color _getReviewTypeColor(String reviewType) {
    switch (reviewType.toLowerCase()) {
      case 'busy':
        return Colors.orange;
      case 'no_answer':
        return Colors.red;
      case 'answered':
        return Colors.green;
      case 'wrong_number':
        return Colors.purple;
      case 'not_interested':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getReviewTypeIcon(String reviewType) {
    switch (reviewType.toLowerCase()) {
      case 'busy':
        return Icons.phone_callback;
      case 'no_answer':
        return Icons.call_missed;
      case 'answered':
        return Icons.call;
      case 'wrong_number':
        return Icons.warning;
      case 'not_interested':
        return Icons.thumb_down;
      default:
        return Icons.rate_review;
    }
  }

  Future<void> _exportReport() async {
    final currentTab = _tabController.index;
    
    if (currentTab == 0 && _reviews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No call notes to export')),
      );
      return;
    }
    if (currentTab == 1 && _logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No call history to export')),
      );
      return;
    }

    try {
      // Create Excel workbook
      final workbook = xls.Excel.createExcel();
      final sheetName = currentTab == 0 ? 'Call Notes' : 'Call History';
      final sheet = workbook[sheetName];

      // Header
      if (currentTab == 0) {
        sheet.appendRow(<xls.CellValue?>[
          xls.TextCellValue('Phone Number'),
          xls.TextCellValue('Name'),
          xls.TextCellValue('Review Type'),
          xls.TextCellValue('Notes'),
          xls.TextCellValue('Date'),
          xls.TextCellValue('Time'),
        ]);
        for (final review in _reviews) {
          final phoneNumber = _phoneNumbers.firstWhere(
            (p) => p.id == review.phoneId,
            orElse: () => PhoneNumber(number: review.phoneNumber),
          );
          sheet.appendRow(<xls.CellValue?>[
            xls.TextCellValue(review.phoneNumber),
            xls.TextCellValue(phoneNumber.name ?? ''),
            xls.TextCellValue(review.reviewType),
            xls.TextCellValue(review.customNote ?? ''),
            xls.TextCellValue('${review.timestamp.day}/${review.timestamp.month}/${review.timestamp.year}'),
            xls.TextCellValue('${review.timestamp.hour}:${review.timestamp.minute.toString().padLeft(2, '0')}'),
          ]);
        }
      } else {
        sheet.appendRow(<xls.CellValue?>[
          xls.TextCellValue('Phone Number'),
          xls.TextCellValue('Name'),
          xls.TextCellValue('Status'),
          xls.TextCellValue('Date'),
          xls.TextCellValue('Time'),
        ]);
        for (final log in _logs) {
          final phoneNumber = _phoneNumbers.firstWhere(
            (p) => p.id == log.phoneId,
            orElse: () => PhoneNumber(number: log.phoneNumber),
          );
          sheet.appendRow(<xls.CellValue?>[
            xls.TextCellValue(log.phoneNumber),
            xls.TextCellValue(phoneNumber.name ?? ''),
            xls.TextCellValue(log.status.name),
            xls.TextCellValue('${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}'),
            xls.TextCellValue('${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}'),
          ]);
        }
      }

      // Save to a file
      final bytes = workbook.encode();
      final nowStr = DateTime.now().toIso8601String().split('T').first;
      final fileName = 'DialDesk_${currentTab == 0 ? 'Call_Notes' : 'Call_History'}_$nowStr.xlsx';

      // Prefer external storage if available, else documents
      final externalDir = await getExternalStorageDirectory();
      final targetDir = externalDir ?? await getApplicationDocumentsDirectory();
      final filePath = p.join(targetDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes!, flush: true);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: fileName)],
        subject: 'DialDesk ${currentTab == 0 ? 'Call Notes' : 'Call History'} Report',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

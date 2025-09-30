import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/call_review.dart';

class ReviewSettingsScreen extends StatefulWidget {
  const ReviewSettingsScreen({super.key});

  @override
  State<ReviewSettingsScreen> createState() => _ReviewSettingsScreenState();
}

class _ReviewSettingsScreenState extends State<ReviewSettingsScreen> {
  final DbHelper _db = DbHelper();
  final TextEditingController _newKeyController = TextEditingController();
  final TextEditingController _newLabelController = TextEditingController();
  final TextEditingController _newMessageController = TextEditingController();
  
  List<ReviewOption> _reviewOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviewOptions();
  }

  Future<void> _loadReviewOptions() async {
    final options = await _db.fetchReviewOptions();
    setState(() {
      _reviewOptions = options;
      _isLoading = false;
    });
  }

  Future<void> _addNewOption() async {
    if (_newKeyController.text.trim().isEmpty ||
        _newLabelController.text.trim().isEmpty ||
        _newMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final option = ReviewOption(
        key: _newKeyController.text.trim(),
        label: _newLabelController.text.trim(),
        message: _newMessageController.text.trim(),
      );

      await _db.insertReviewOption(option);
      await _loadReviewOptions();

      _newKeyController.clear();
      _newLabelController.clear();
      _newMessageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review option added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding option: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOption(ReviewOption option) async {
    final keyController = TextEditingController(text: option.key);
    final labelController = TextEditingController(text: option.label);
    final messageController = TextEditingController(text: option.message);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Review Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Key (unique identifier)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label (display name)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message (description)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop({
              'key': keyController.text.trim(),
              'label': labelController.text.trim(),
              'message': messageController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final updatedOption = ReviewOption(
          key: result['key']!,
          label: result['label']!,
          message: result['message']!,
        );

        await _db.updateReviewOption(updatedOption);
        await _loadReviewOptions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review option updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating option: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteOption(ReviewOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review Option'),
        content: Text('Are you sure you want to delete "${option.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteReviewOption(option.key);
        await _loadReviewOptions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review option deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting option: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _newKeyController.dispose();
    _newLabelController.dispose();
    _newMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call Review Options',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Customize the review options that appear when reviewing calls.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  
                  // Add new option form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Review Option',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _newKeyController,
                            decoration: const InputDecoration(
                              labelText: 'Key (unique identifier)',
                              hintText: 'e.g., interested',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newLabelController,
                            decoration: const InputDecoration(
                              labelText: 'Label (display name)',
                              hintText: 'e.g., Interested',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newMessageController,
                            decoration: const InputDecoration(
                              labelText: 'Message (description)',
                              hintText: 'e.g., Customer showed interest',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addNewOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Existing options list
                  const Text(
                    'Current Review Options',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _reviewOptions.length,
                    itemBuilder: (context, index) {
                      final option = _reviewOptions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(option.label),
                          subtitle: Text(option.message),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _updateOption(option),
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _deleteOption(option),
                                icon: const Icon(Icons.delete),
                                tooltip: 'Delete',
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}


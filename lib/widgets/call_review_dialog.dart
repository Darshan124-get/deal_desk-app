import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/call_review.dart';
import '../models/phone_number.dart';

class CallReviewDialog extends StatefulWidget {
  final PhoneNumber phoneNumber;
  final VoidCallback onReviewSubmitted;

  const CallReviewDialog({
    super.key,
    required this.phoneNumber,
    required this.onReviewSubmitted,
  });

  @override
  State<CallReviewDialog> createState() => _CallReviewDialogState();
}

class _CallReviewDialogState extends State<CallReviewDialog> {
  final DbHelper _db = DbHelper();
  final TextEditingController _customNoteController = TextEditingController();
  List<ReviewOption> _reviewOptions = [];
  String? _selectedReviewType;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadReviewOptions();
  }

  Future<void> _loadReviewOptions() async {
    try {
      // Add a small delay to ensure database is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final options = await _db.fetchReviewOptions();
      if (mounted) {
        setState(() {
          _reviewOptions = options.isNotEmpty ? options : _getDefaultOptions();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewOptions = _getDefaultOptions();
          _isLoading = false;
        });
        if (kDebugMode) {
          print('Error loading review options: $e');
        }
      }
    }
  }

  List<ReviewOption> _getDefaultOptions() {
    return [
      ReviewOption(key: 'busy', label: 'Busy', message: 'Line was busy'),
      ReviewOption(key: 'no_answer', label: 'No Answer', message: 'No one answered'),
      ReviewOption(key: 'answered', label: 'Answered', message: 'Call was answered'),
      ReviewOption(key: 'wrong_number', label: 'Wrong Number', message: 'Wrong number'),
      ReviewOption(key: 'not_interested', label: 'Not Interested', message: 'Not interested'),
    ];
  }

  Future<void> _submitReview() async {
    if (_selectedReviewType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a review option'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final review = CallReview(
        phoneId: widget.phoneNumber.id ?? 0,
        phoneNumber: widget.phoneNumber.number,
        reviewType: _selectedReviewType!,
        customNote: _customNoteController.text.trim().isNotEmpty 
            ? _customNoteController.text.trim() 
            : null,
        timestamp: DateTime.now(),
      );

      await _db.insertCallReview(review);
      
      // Mark the number as completed
      if (widget.phoneNumber.id != null) {
        await _db.markCompleted(widget.phoneNumber.id!);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onReviewSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading review options...'),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Review Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Phone Number Display
                  Text(
                    widget.phoneNumber.number,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  
                  // Review Options as Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reviewOptions.map((option) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedReviewType = option.key;
                          _customNoteController.text = option.message;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedReviewType == option.key
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedReviewType == option.key
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: _selectedReviewType == option.key
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Review Notes Text Area
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _customNoteController,
                      maxLines: 4,
                      enableInteractiveSelection: true,
                      decoration: const InputDecoration(
                        hintText: 'Review notes here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onTap: () {
                        // Select all text when tapping the field
                        _customNoteController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _customNoteController.text.length,
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}


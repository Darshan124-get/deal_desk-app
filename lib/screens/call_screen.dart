import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import '../data/db_helper.dart';
import '../models/app_settings.dart';
import '../models/call_log.dart';
import '../models/phone_number.dart';
import '../widgets/call_review_dialog.dart';

import '../services/background_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}


class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final DbHelper _db = DbHelper();
  PhoneNumber? _current;

  List<PhoneNumber> _allNumbers = [];
  AppSettings _settings = const AppSettings();
  int _countdown = 0;
  Timer? _timer;
  bool _autoAdvance = false;
  bool _isLoading = true;

  bool _isAutoCalling = false;
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isCallActive = false;
  Timer? _callTimer;
  bool _isBackgroundServiceRunning = false;
  bool _wasInBackground = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final settings = await _db.fetchSettings();
    await _loadAllNumbers();
    await _checkBackgroundServiceStatus();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data whenever screen becomes active again
    _loadAllNumbers();
  }


  Future<void> _checkBackgroundServiceStatus() async {
    final isRunning = await BackgroundCallService.isServiceRunning();
    setState(() {
      _isBackgroundServiceRunning = isRunning;
    });
  }

  Future<void> _loadAllNumbers() async {
    final numbers = await _db.fetchAllNumbers();
    if (kDebugMode) {
      print('DEBUG: Loaded ${numbers.length} numbers from database');
      for (int i = 0; i < numbers.length; i++) {
        print('DEBUG: Number $i: ${numbers[i].number} (completed: ${numbers[i].completed})');
      }
    }
    
    // Show all numbers (both completed and pending)
    setState(() {
      _allNumbers = numbers;
      // Find the first pending number for current call
      final pendingNumbers = numbers.where((n) => !n.completed).toList();
      if (kDebugMode) {
        print('DEBUG: Found ${pendingNumbers.length} pending numbers');
      }
      if (pendingNumbers.isNotEmpty) {
        _current = pendingNumbers[0];
        _currentIndex = numbers.indexOf(pendingNumbers[0]);
        if (kDebugMode) {
          print('DEBUG: Current number set to: ${_current!.number} at index $_currentIndex');
        }
      } else {
        _current = null;
        _currentIndex = 0;
        if (kDebugMode) {
          print('DEBUG: No pending numbers found, current set to null');
        }
      }
    });
  }

  Future<void> _requestCallPermission() async {
    final status = await Permission.phone.status;
    if (status.isGranted) return;
    await Permission.phone.request();
  }


  Future<void> _deleteNumber(PhoneNumber number) async {
    if (number.id != null) {
      await _db.deleteNumber(number.id!);
      await _loadAllNumbers();
    }
  }

  Future<void> _pauseAutoCalling() async {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
    _callTimer?.cancel();
    _animationController.stop();
  }

  Future<void> _resumeAutoCalling() async {
    setState(() {
      _isPaused = false;
    });
    _animationController.repeat(reverse: true);
    // Continue with the current call or start countdown
    if (_isCallActive) {
      _startCallTimer();
    } else {
      _startAutoAdvanceCountdown();
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    setState(() {
      _isCallActive = true;
    });
    
    // Start a shorter timer that assumes the call will end quickly
    // This gives the teacher time to talk, and then automatically advances
    _callTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && _isCallActive) {
        setState(() {
          _isCallActive = false;
        });
        if (_isAutoCalling) {
          _onCallEnded();
        }
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    setState(() {
      _isCallActive = false;
    });
  }

  Future<void> _onCallEnded() async {
    // When call ends automatically, start the countdown
    // The teacher can still manually change the status if needed during the countdown
    if (_isAutoCalling) {
      _startAutoAdvanceCountdown();
    }
  }

  Future<void> _autoAdvanceToNext() async {
    // This is called when the countdown finishes
    // Mark the current call as completed and move to next
    if (_current != null && _current!.id != null) {
      await _db.markCompleted(_current!.id!);
    }
    
    // This will automatically call the next number if auto-calling is active
    await _advanceToNextNumber();
  }

  Future<void> _startCall() async {
    if (_current == null) return;
    await _requestCallPermission();
    await FlutterPhoneDirectCaller.callNumber(_current!.number);

    // Log the call immediately when it's initiated
    final now = DateTime.now();
    final log = CallLog(
      phoneId: _current!.id ?? 0,
      phoneNumber: _current!.number,
      status: CallStatus.completed, // Mark as completed when call is made
      timestamp: now,
    );
    await _db.insertLog(log);
    
    if (kDebugMode) {
      print('DEBUG: Call logged for ${_current!.number} at ${now.toString()}');
    }
    
    // Start the call timer when call is initiated
    if (_isAutoCalling) {
      _startCallTimer();
    }
  }

  Future<void> _startAutoCalling() async {
    if (_allNumbers.isEmpty) return;
    
    setState(() {
      _isAutoCalling = true;
      _isPaused = false;
      _currentIndex = 0;
      _current = _allNumbers[_currentIndex];
    });
    
    _animationController.repeat(reverse: true);
    
    // Start the first call (avoid starting background isolate in release)
    await _startCall();
  }

  Future<void> _stopAutoCalling() async {
    _timer?.cancel();
    _callTimer?.cancel();
    _animationController.stop();
    
    // Stop background service
    await BackgroundCallService.stopAutoCalling();
    await _checkBackgroundServiceStatus();
    
    setState(() {
      _isAutoCalling = false;
      _isPaused = false;
      _autoAdvance = false;
      _isCallActive = false;
    });
  }

  Future<void> _markAndAdvance(CallStatus status) async {
    if (_current == null) return;
    
    final now = DateTime.now();
    final log = CallLog(
      phoneId: _current!.id ?? 0,
      phoneNumber: _current!.number,
      status: status,
      timestamp: now,
    );
    await _db.insertLog(log);

    if (_current!.id != null) {
      if (status == CallStatus.completed || status == CallStatus.skipped) {
        await _db.markCompleted(_current!.id!);
      }
    }

    if (_isAutoCalling && status == CallStatus.completed) {
      await _advanceToNextNumber();
    } else {
      await _loadAllNumbers();
      _startAutoAdvanceCountdown();
    }
  }

  Future<void> _showReviewDialog() async {
    if (_current == null) return;
    
    await showDialog(
      context: context,
      builder: (context) => CallReviewDialog(
        phoneNumber: _current!,
        onReviewSubmitted: () async {
          await _loadAllNumbers();
          if (_isAutoCalling) {
            await _advanceToNextNumber();
          } else {
            _startAutoAdvanceCountdown();
          }
        },
      ),
    );
  }

  Future<void> _callSpecificNumber(PhoneNumber number) async {
    await _requestCallPermission();
    await FlutterPhoneDirectCaller.callNumber(number.number);
    
    // Log the call
    final now = DateTime.now();
    final log = CallLog(
      phoneId: number.id ?? 0,
      phoneNumber: number.number,
      status: CallStatus.completed,
      timestamp: now,
    );
    await _db.insertLog(log);
    
    if (kDebugMode) {
      print('DEBUG: Manual call logged for ${number.number} at ${now.toString()}');
    }
  }

  Future<void> _reviewSpecificNumber(PhoneNumber number) async {
    await showDialog(
      context: context,
      builder: (context) => CallReviewDialog(
        phoneNumber: number,
        onReviewSubmitted: () async {
          await _loadAllNumbers();
        },
      ),
    );
  }

  Future<void> _advanceToNextNumber() async {
    // Find next pending number
    int nextIndex = _currentIndex + 1;
    while (nextIndex < _allNumbers.length && _allNumbers[nextIndex].completed) {
      nextIndex++;
    }
    
    if (nextIndex >= _allNumbers.length) {
      // All numbers completed
      await _stopAutoCalling();
      await _loadAllNumbers();
      _showCompletionDialog();
      return;
    }
    
    setState(() {
      _currentIndex = nextIndex;
      _current = _allNumbers[_currentIndex];
    });
    
    // If auto-calling is active and not paused, immediately call the next number
    if (_isAutoCalling && !_isPaused) {
      await _startCall();
    } else {
    _startAutoAdvanceCountdown();

    }
  }

  void _startAutoAdvanceCountdown() {
    _timer?.cancel();
    setState(() {
      _countdown = _settings.callDelaySeconds;
      _autoAdvance = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) {
          setState(() {
            _autoAdvance = false;
          });
        }

        // Auto advance to next call only if not paused
        if (_isAutoCalling && !_isPaused) {
          _autoAdvanceToNext();
        }
        return;
      }

      if (mounted && !_isPaused) {
        setState(() {

          _countdown--;
        });
      }
    });
  }


  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Calls Completed'),
        content: const Text('You have completed calling all numbers.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(PhoneNumber number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Number'),
        content: Text('Are you sure you want to delete ${number.number}${number.name != null ? ' (${number.name})' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNumber(number);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Numbers'),
        content: Text('Are you sure you want to delete all ${_allNumbers.length} phone numbers? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAllNumbers();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllNumbers() async {
    await _db.clearAllNumbers();
    await _loadAllNumbers();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All phone numbers have been deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {

    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();

    _callTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App went to background (call started)
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground && _isCallActive && _isAutoCalling) {
      // App came back to foreground (call ended)
      _wasInBackground = false;
      _stopCallTimer();
      _onCallEnded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberText = _current?.number ?? '-';
    return Scaffold(

      appBar: AppBar(
        title: Text(_isAutoCalling ? 'Auto Calling' : 'Call'),
        backgroundColor: _isAutoCalling ? Colors.green : null,
        foregroundColor: _isAutoCalling ? Colors.white : null,
        actions: [
          if (_isBackgroundServiceRunning)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Background',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (_allNumbers.isNotEmpty && !_isAutoCalling)
            IconButton(
              onPressed: _showDeleteAllDialog,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete All Numbers',
            ),
          if (_isAutoCalling)
            IconButton(
              onPressed: _stopAutoCalling,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop Auto Calling',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())

          : SingleChildScrollView(
              child: Column(
                children: [
                  // Current number display with animation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: _isAutoCalling 
                          ? LinearGradient(
                              colors: [Colors.green.shade50, Colors.blue.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
              child: Column(
                children: [
                  const Text('Current Number:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),

                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isAutoCalling ? _scaleAnimation.value : 1.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isAutoCalling 
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isAutoCalling 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                    width: 2,
                                  ),
                                  boxShadow: _isAutoCalling ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ] : null,
                                ),
                                child: Text(
                                  numberText,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: _isAutoCalling 
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (_isAutoCalling) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_currentIndex + 1} of ${_allNumbers.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_isPaused) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pause,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Auto-calling Paused',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_isCallActive) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Call Active - Auto-advance in 2 min',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                _stopCallTimer();
                                if (_isAutoCalling) {
                                  _onCallEnded();
                                }
                              },
                              icon: const Icon(Icons.call_end),
                              label: const Text('End Call & Continue'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                  if (_autoAdvance) ...[
                    const SizedBox(height: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Next call in $_countdown s',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        setState(() => _autoAdvance = false);

                              if (_isAutoCalling) {
                                _autoAdvanceToNext();
                              }
                            },
                            child: const Text('Skip Wait & Call Next'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Phone number list
                  Container(
                    height: 300, // Fixed height to prevent overflow
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Phone Numbers (${_allNumbers.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Pending: ${_allNumbers.where((n) => !n.completed).length}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _allNumbers.length,
                            itemBuilder: (context, index) {
                              final number = _allNumbers[index];
                              final isCurrent = _isAutoCalling && index == _currentIndex;
                              final isCompleted = number.completed;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: isCurrent 
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                      : isCompleted
                                          ? Theme.of(context).colorScheme.surfaceVariant
                                          : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCurrent 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isCurrent 
                                        ? Theme.of(context).colorScheme.primary
                                        : isCompleted
                                            ? Theme.of(context).colorScheme.secondary
                                            : Theme.of(context).colorScheme.outline,
                                    child: Icon(
                                      isCurrent 
                                          ? Icons.phone
                                          : isCompleted
                                              ? Icons.check
                                              : Icons.phone_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  title: Text(
                                    number.number,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCompleted 
                                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                  subtitle: number.name != null 
                                      ? Text(
                                          number.name!,
                                          style: TextStyle(
                                            color: isCompleted 
                                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                                : null,
                                          ),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrent)
                                        AnimatedBuilder(
                                          animation: _scaleAnimation,
                                          builder: (context, child) {
                                            return Transform.scale(
                                              scale: _scaleAnimation.value,
                                              child: Icon(
                                                Icons.radio_button_checked,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            );
                                          },
                                        ),
                                      if (!_isAutoCalling) ...[
                                        IconButton(
                                          onPressed: () => _callSpecificNumber(number),
                                          icon: Icon(
                                            Icons.phone,
                                            color: Colors.green.shade600,
                                            size: 20,
                                          ),
                                          tooltip: 'Call',
                                        ),
                                        IconButton(
                                          onPressed: () => _reviewSpecificNumber(number),
                                          icon: Icon(
                                            Icons.rate_review,
                                            color: Colors.blue.shade600,
                                            size: 20,
                                          ),
                                          tooltip: 'Review',
                                        ),
                                        IconButton(
                                          onPressed: () => _showDeleteDialog(number),
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red.shade600,
                                            size: 20,
                                          ),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Control buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_isBackgroundServiceRunning)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Auto-advance enabled: When you end a call, app automatically moves to next number.',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(

                                onPressed: _isAutoCalling 
                                    ? (_isPaused ? _resumeAutoCalling : _pauseAutoCalling)
                                    : null,
                                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(_isPaused ? 'Resume' : 'Pause'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPaused ? Colors.green : Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _current == null || _isAutoCalling 
                              ? null
                              : () => _markAndAdvance(CallStatus.skipped),
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(

                                onPressed: _isAutoCalling 
                                    ? _stopAutoCalling 
                                    : _allNumbers.isEmpty 
                              ? null

                                        : _startAutoCalling,
                                icon: Icon(_isAutoCalling ? Icons.stop : Icons.play_arrow),
                                label: Text(_isAutoCalling ? 'Stop Auto Call' : 'Start Auto Call'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAutoCalling ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                    ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


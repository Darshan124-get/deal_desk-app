import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/db_helper.dart';
import '../models/app_settings.dart';
import '../models/call_log.dart';
import '../models/phone_number.dart';

@pragma('vm:entry-point')
class BackgroundCallService {
  static const String _channelId = 'dialdesk_calling_service';
  static const String _channelName = 'DialDesk Auto Calling';
  static const String _channelDescription = 'Auto-calling service for DialDesk app';

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: _channelName,
        initialNotificationContent: 'Auto-calling service is ready',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Do not register plugins in background isolate to avoid release crashes

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Auto-calling logic
    service.on('startAutoCalling').listen((event) async {
      await _startAutoCallingProcess(service);
    });

    // Update notification
    service.on('updateNotification').listen((event) {
      final title = event?['title'] ?? 'DialDesk Auto Calling';
      final content = event?['content'] ?? 'Auto-calling in progress';
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    });
  }

  static Future<void> _startAutoCallingProcess(ServiceInstance service) async {
    try {
      final db = DbHelper();
      final settings = await db.fetchSettings();
      final numbers = await db.fetchPendingNumbers();
      
      if (numbers.isEmpty) {
        await _updateNotification(service, 'Auto Calling Complete', 'All numbers have been called');
        return;
      }

      int currentIndex = 0;
      
      while (currentIndex < numbers.length) {
        final currentNumber = numbers[currentIndex];
        
        // Update notification with current progress
        await _updateNotification(
          service, 
          'Auto Calling', 
          'Calling ${currentIndex + 1}/${numbers.length}: ${currentNumber.number}'
        );

        // Make the call
        await _makeCall(currentNumber.number);
        
        // Wait for call to complete (5 minutes max)
        await Future.delayed(const Duration(minutes: 5));
        
        // Mark as completed and log
        await _logCall(db, currentNumber, CallStatus.completed);
        await db.markCompleted(currentNumber.id!);
        
        // Wait between calls
        await _updateNotification(
          service, 
          'Auto Calling', 
          'Waiting ${settings.callDelaySeconds}s before next call...'
        );
        await Future.delayed(Duration(seconds: settings.callDelaySeconds));
        
        currentIndex++;
      }
      
      // All calls completed
      await _updateNotification(service, 'Auto Calling Complete', 'All numbers have been called');
      
    } catch (e) {
      await _updateNotification(service, 'Auto Calling Error', 'Error: $e');
    }
  }

  static Future<void> _makeCall(String phoneNumber) async {
    try {
      // Request permission
      final permission = await Permission.phone.request();
      if (permission.isGranted) {
        await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      }
    } catch (e) {
      print('Error making call: $e');
    }
  }

  static Future<void> _logCall(DbHelper db, PhoneNumber number, CallStatus status) async {
    try {
      final log = CallLog(
        phoneId: number.id ?? 0,
        phoneNumber: number.number,
        status: status,
        timestamp: DateTime.now(),
      );
      await db.insertLog(log);
    } catch (e) {
      print('Error logging call: $e');
    }
  }

  static Future<void> _updateNotification(ServiceInstance service, String title, String content) async {
    // No-op on background isolate to avoid Android-specific API usage
    // Keep logic minimal to prevent plugin usage outside main isolate
  }

  static Future<void> startAutoCalling() async {
    final service = FlutterBackgroundService();
    // Ensure configured lazily before start
    await initializeService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    service.invoke('startAutoCalling');
  }

  static Future<void> stopAutoCalling() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}

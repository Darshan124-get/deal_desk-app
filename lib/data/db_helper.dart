import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/call_log.dart';
import '../models/phone_number.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'dialdesk.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE numbers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT NOT NULL,
            name TEXT,
            completed INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await db.execute('''
          CREATE TABLE call_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_id INTEGER NOT NULL,
            phone_number TEXT NOT NULL,
            status TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY(phone_id) REFERENCES numbers(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            call_delay_seconds INTEGER NOT NULL,
            dark_mode INTEGER NOT NULL
          );
        ''');
        await db.insert('settings', const AppSettings().toMap()..['id'] = 1);
      },
    );
  }

  // Numbers
  Future<int> insertNumber(PhoneNumber number) async {
    final db = await database;
    return db.insert('numbers', number.toMap());
  }

  Future<void> insertNumbers(List<PhoneNumber> numbers) async {
    final db = await database;
    final batch = db.batch();
    for (final n in numbers) {
      batch.insert('numbers', n.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllNumbers(List<PhoneNumber> numbers) async {
    final db = await database;
    if (kDebugMode) {
      print('DEBUG: Starting replaceAllNumbers with ${numbers.length} numbers');
    }
    
    final batch = db.batch();
    // Clear all existing numbers
    batch.delete('numbers');
    if (kDebugMode) {
      print('DEBUG: Cleared existing numbers from database');
    }
    
    // Insert new numbers
    for (int i = 0; i < numbers.length; i++) {
      final number = numbers[i];
      final map = number.toMap();
      if (kDebugMode) {
        print('DEBUG: Inserting number $i: $map');
      }
      batch.insert('numbers', map);
    }
    
    await batch.commit(noResult: true);
    if (kDebugMode) {
      print('DEBUG: Batch commit completed');
    }
    
    // Verify the insert
    final count = await totalCount();
    if (kDebugMode) {
      print('DEBUG: Total numbers in database after replace: $count');
    }
  }

  Future<List<PhoneNumber>> fetchPendingNumbers() async {
    final db = await database;
    final rows = await db.query('numbers', where: 'completed = 0');
    return rows.map((e) => PhoneNumber.fromMap(e)).toList();
  }

  Future<List<PhoneNumber>> fetchAllNumbers() async {
    final db = await database;
    final rows = await db.query('numbers', orderBy: 'id ASC');
    return rows.map((e) => PhoneNumber.fromMap(e)).toList();
  }

  Future<void> markCompleted(int id) async {
    final db = await database;
    await db.update('numbers', {'completed': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNumber(int id) async {
    final db = await database;
    await db.delete('numbers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllNumbers() async {
    final db = await database;
    await db.delete('numbers');
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM numbers WHERE completed = 0'));
    return result ?? 0;
  }

  Future<int> completedCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM numbers WHERE completed = 1'));
    return result ?? 0;
  }

  Future<int> totalCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM numbers'));
    return result ?? 0;
  }

  // Call logs
  Future<int> insertLog(CallLog log) async {
    final db = await database;
    return db.insert('call_logs', log.toMap());
  }

  Future<List<CallLog>> fetchLogs({DateTime? from, DateTime? to, CallStatus? status}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query('call_logs', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'timestamp DESC');
    return rows.map((e) => CallLog.fromMap(e)).toList();
  }

  // Settings
  Future<AppSettings> fetchSettings() async {
    final db = await database;
    final rows = await db.query('settings', where: 'id = 1');
    if (rows.isEmpty) return const AppSettings();
    return AppSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;
    await db.insert('settings', settings.toMap()..['id'] = 1, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

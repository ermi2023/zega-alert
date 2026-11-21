import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'zega_alert.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE announcements (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE missing_persons (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE wanted_persons (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await _createOutbox(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createOutbox(db);
      },
    );
  }

  // Offline outbox: writes made while offline are queued here and flushed
  // automatically once connectivity returns (doc: offline reporting support).
  static Future<void> _createOutbox(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> enqueue(String method, String path, Map<String, dynamic>? body) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('web_outbox') ?? [];
      list.add(jsonEncode({
        'id': DateTime.now().millisecondsSinceEpoch,
        'method': method,
        'path': path,
        'body': body == null ? null : jsonEncode(body),
        'attempts': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }));
      await prefs.setStringList('web_outbox', list);
      return;
    }
    final db = await database;
    await db?.insert('outbox', {
      'method': method,
      'path': path,
      'body': body == null ? null : jsonEncode(body),
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, Object?>>> getOutbox() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('web_outbox') ?? [];
      return list.map((e) => Map<String, Object?>.from(jsonDecode(e) as Map)).toList();
    }
    final db = await database;
    if (db == null) return [];
    return db.query('outbox', orderBy: 'created_at ASC');
  }

  static Future<int> outboxCount() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('web_outbox') ?? []).length;
    }
    final db = await database;
    if (db == null) return 0;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (result.first['c'] as int?) ?? 0;
  }

  static Future<void> removeOutbox(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('web_outbox') ?? [];
      list.removeWhere((e) {
        final m = jsonDecode(e) as Map;
        return m['id'] == id;
      });
      await prefs.setStringList('web_outbox', list);
      return;
    }
    final db = await database;
    await db?.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> bumpAttempts(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db?.rawUpdate('UPDATE outbox SET attempts = attempts + 1 WHERE id = ?', [id]);
  }

  static Future<void> cacheList(String table, List<dynamic> items) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$table', jsonEncode(items));
      return;
    }
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    batch.delete(table);
    for (final item in items) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        batch.insert(table, {
          'id': id,
          'data': jsonEncode(item),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  static Future<List<dynamic>> getCachedList(String table) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cache_$table');
      if (raw == null) return [];
      try {
        return jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        return [];
      }
    }
    final db = await database;
    if (db == null) return [];
    final rows = await db.query(table, orderBy: 'updated_at DESC');
    return rows.map((r) => jsonDecode(r['data'] as String) as dynamic).toList();
  }

  static Future<void> cacheValue(String key, dynamic value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_value_$key', jsonEncode(value));
      return;
    }
    final db = await database;
    await db?.insert('cache', {
      'key': key,
      'value': jsonEncode(value),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<dynamic> getCachedValue(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cache_value_$key');
      if (raw == null) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final rows = await db?.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows == null || rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['value'] as String);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_announcements');
      await prefs.remove('cache_reports');
      await prefs.remove('cache_missing_persons');
      await prefs.remove('cache_wanted_persons');
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.delete('announcements');
    await db.delete('reports');
    await db.delete('missing_persons');
    await db.delete('wanted_persons');
  }
}

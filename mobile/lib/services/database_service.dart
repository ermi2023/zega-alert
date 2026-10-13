import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
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
    final db = await database;
    await db.insert('outbox', {
      'method': method,
      'path': path,
      'body': body == null ? null : jsonEncode(body),
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, Object?>>> getOutbox() async {
    final db = await database;
    return db.query('outbox', orderBy: 'created_at ASC');
  }

  static Future<int> outboxCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (result.first['c'] as int?) ?? 0;
  }

  static Future<void> removeOutbox(int id) async {
    final db = await database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> bumpAttempts(int id) async {
    final db = await database;
    await db.rawUpdate('UPDATE outbox SET attempts = attempts + 1 WHERE id = ?', [id]);
  }

  static Future<void> cacheList(String table, List<dynamic> items) async {
    final db = await database;
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
    final db = await database;
    final rows = await db.query(table, orderBy: 'updated_at DESC');
    return rows.map((r) => jsonDecode(r['data'] as String) as dynamic).toList();
  }

  static Future<void> clearCache() async {
    final db = await database;
    await db.delete('announcements');
    await db.delete('reports');
    await db.delete('missing_persons');
    await db.delete('wanted_persons');
  }
}

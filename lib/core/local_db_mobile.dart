import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_db_interface.dart';

class LocalDbMobile implements LocalDb {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;

    final dir = await getDatabasesPath();
    final path = p.join(dir, 'songs_firestore_rest.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE songs (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            key_name TEXT NOT NULL,
            chord_pro TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL,
            deleted INTEGER NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            song_id TEXT NOT NULL,
            op TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE meta (
            k TEXT PRIMARY KEY,
            v TEXT NOT NULL
          );
        ''');

        await d.insert('meta', {'k': 'last_sync', 'v': '0'});
      },
    );

    return _db!;
  }

  @override
  Future<void> init() async {
    await _database;
  }

  @override
  Future<int> getLastSync() async {
    final db = await _database;
    final rows = await db.query(
      'meta',
      where: 'k=?',
      whereArgs: ['last_sync'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['v'] as String) ?? 0;
  }

  @override
  Future<void> setLastSync(int ts) async {
    final db = await _database;
    await db.update(
      'meta',
      {'v': ts.toString()},
      where: 'k=?',
      whereArgs: ['last_sync'],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listSongs() async {
    final db = await _database;
    return db.query(
      'songs',
      where: 'deleted=0',
      orderBy: 'updated_at DESC',
    );
  }

  @override
  Future<Map<String, dynamic>?> getSong(String id) async {
    final db = await _database;
    final rows = await db.query(
      'songs',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  @override
  Future<void> upsertSong(Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert('songs', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> markDeleted(String id, int updatedAt) async {
    final db = await _database;
    await db.update(
      'songs',
      {
        'deleted': 1,
        'dirty': 1,
        'updated_at': updatedAt,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markClean(String id, {int? updatedAt}) async {
    final db = await _database;
    final updates = <String, Object?>{'dirty': 0};
    if (updatedAt != null) {
      updates['updated_at'] = updatedAt;
    }
    await db.update('songs', updates, where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<void> enqueue(Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert('outbox', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> outbox() async {
    final db = await _database;
    return db.query('outbox', orderBy: 'created_at ASC');
  }

  @override
  Future<void> removeOutbox(String id) async {
    final db = await _database;
    await db.delete('outbox', where: 'id=?', whereArgs: [id]);
  }
}

LocalDb createLocalDbImpl() => LocalDbMobile();
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

import 'local_db_interface.dart';

class LocalDbWeb implements LocalDb {
  Database? _db;

  final _songsStore = stringMapStoreFactory.store('songs');
  final _outboxStore = stringMapStoreFactory.store('outbox');
  final _metaStore = stringMapStoreFactory.store('meta');

  Future<Database> get _database async {
    if (_db != null) return _db!;

    _db = await databaseFactoryWeb.openDatabase('songs_firestore_rest.db');

    final lastSync = await _metaStore.record('last_sync').get(_db!);
    if (lastSync == null) {
      await _metaStore.record('last_sync').put(_db!, {'v': '0'});
    }

    return _db!;
  }

  @override
  Future<void> init() async {
    await _database;
  }

  @override
  Future<int> getLastSync() async {
    final db = await _database;
    final row = await _metaStore.record('last_sync').get(db);
    if (row == null) return 0;
    return int.tryParse('${row['v']}') ?? 0;
  }

  @override
  Future<void> setLastSync(int ts) async {
    final db = await _database;
    await _metaStore.record('last_sync').put(db, {'v': ts.toString()});
  }

  @override
  Future<List<Map<String, dynamic>>> listSongs() async {
    final db = await _database;
    final records = await _songsStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('updated_at', false)]),
    );

    return records
        .map((e) => Map<String, dynamic>.from(e.value))
        .where((e) => (e['deleted'] ?? 0) == 0)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getSong(String id) async {
    final db = await _database;
    final row = await _songsStore.record(id).get(db);
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<void> upsertSong(Map<String, dynamic> data) async {
    final db = await _database;
    final id = data['id'] as String;
    await _songsStore.record(id).put(db, data);
  }

  @override
  Future<void> markDeleted(String id, int updatedAt) async {
    final db = await _database;
    final row = await _songsStore.record(id).get(db);
    if (row == null) return;

    final updated = Map<String, dynamic>.from(row);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = updatedAt;

    await _songsStore.record(id).put(db, updated);
  }

  @override
  Future<void> markClean(String id, {int? updatedAt}) async {
    final db = await _database;
    final row = await _songsStore.record(id).get(db);
    if (row == null) return;

    final updated = Map<String, dynamic>.from(row);
    updated['dirty'] = 0;
    if (updatedAt != null) {
      updated['updated_at'] = updatedAt;
    }

    await _songsStore.record(id).put(db, updated);
  }

  @override
  Future<void> enqueue(Map<String, dynamic> data) async {
    final db = await _database;
    final id = data['id'] as String;
    await _outboxStore.record(id).put(db, data);
  }

  @override
  Future<List<Map<String, dynamic>>> outbox() async {
    final db = await _database;
    final records = await _outboxStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('created_at')]),
    );
    return records.map((e) => Map<String, dynamic>.from(e.value)).toList();
  }

  @override
  Future<void> removeOutbox(String id) async {
    final db = await _database;
    await _outboxStore.record(id).delete(db);
  }
}

LocalDb createLocalDbImpl() => LocalDbWeb();
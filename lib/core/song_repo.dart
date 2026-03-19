import 'local_db.dart';
import 'models.dart';

class SongRepo {
  final LocalDb local;
  SongRepo(this.local);

  Future<List<Song>> listSongs() async {
    final rows = await local.listSongs();
    return rows.map((r) => Song.fromDb(r)).toList();
  }

  Future<Song?> getSong(String id) async {
    final row = await local.getSong(id);
    if (row == null) return null;
    return Song.fromDb(row);
  }

  Future<void> upsertSong(Song s) async {
    await local.upsertSong(s.toDb());
  }

  Future<void> markDeleted(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await local.markDeleted(id, now);
  }

  Future<void> enqueue(OutboxItem it) async {
    await local.enqueue(it.toDb());
  }

  Future<List<OutboxItem>> outbox() async {
    final rows = await local.outbox();
    return rows.map((r) => OutboxItem.fromDb(r)).toList();
  }

  Future<void> removeOutbox(String id) async {
    await local.removeOutbox(id);
  }

  Future<void> markClean(String songId, {int? updatedAt}) async {
    await local.markClean(songId, updatedAt: updatedAt);
  }
}
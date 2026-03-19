import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'firestore_rest.dart';
import 'local_db.dart';
import 'models.dart';
import 'song_repo.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  const SyncResult({required this.pushed, required this.pulled});
}

class SyncService {
  final FirestoreRestClient fs;
  final SongRepo repo;
  final LocalDb local;
  final _uuid = const Uuid();

  SyncService({
    required this.fs,
    required this.repo,
    required this.local,
  });

  Future<bool> get _online async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> queueUpsert(Song s) async {
    await repo.upsertSong(
      s.copyWith(
        dirty: true,
        deleted: false,
      ),
    );

    await repo.enqueue(
      OutboxItem(
        id: _uuid.v4(),
        songId: s.id,
        op: 'upsert',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> queueDelete(String songId) async {
    await repo.markDeleted(songId);

    await repo.enqueue(
      OutboxItem(
        id: _uuid.v4(),
        songId: songId,
        op: 'delete',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<SyncResult> syncNow() async {
    if (!await _online) {
      return const SyncResult(pushed: 0, pulled: 0);
    }

    int pushed = 0;
    int pulled = 0;

    final outbox = await repo.outbox();

    for (final item in outbox) {
      final song = await repo.getSong(item.songId);

      if (song == null) {
        await repo.removeOutbox(item.id);
        continue;
      }

      try {
        if (item.op == 'upsert') {
          await fs.upsertSong(
            docId: song.id,
            songFields: song.toServerFields(),
          );
          await repo.markClean(song.id);
          pushed++;
        } else if (item.op == 'delete') {
          try {
            await fs.deleteSong(docId: song.id);
          } catch (_) {}
          await repo.markClean(song.id);
          pushed++;
        }

        await repo.removeOutbox(item.id);
      } catch (_) {
        break;
      }
    }

    final lastSync = await local.getLastSync();
    final changes = await fs.getChangesSince(since: lastSync);

    int maxTs = lastSync;

    for (final c in changes) {
      final id = (c['id'] as String?) ?? '';
      if (id.isEmpty) continue;

      final localSong = await repo.getSong(id);
      if (localSong != null && localSong.dirty) continue;

      final updatedAt = (c['updatedAt'] is int)
          ? c['updatedAt'] as int
          : int.tryParse('${c['updatedAt']}') ?? 0;

      final s = Song(
        id: id,
        title: (c['title'] ?? '') as String,
        artist: (c['artist'] ?? '') as String,
        keyName: (c['keyName'] ?? 'C') as String,
        chordPro: (c['chordPro'] ?? '') as String,
        updatedAt: updatedAt,
        dirty: false,
        deleted: (c['deleted'] ?? false) == true,
      );

      await repo.upsertSong(s);
      pulled++;

      if (updatedAt > maxTs) {
        maxTs = updatedAt;
      }
    }

    if (maxTs != lastSync) {
      await local.setLastSync(maxTs);
    }

    return SyncResult(pushed: pushed, pulled: pulled);
  }
}
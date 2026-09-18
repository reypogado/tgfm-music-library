import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'firestore_rest.dart';
import 'local_db.dart';
import 'models.dart';
import 'playlist_repo.dart';
import 'song_repo.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  const SyncResult({required this.pushed, required this.pulled});
}

/// Firestore collection names and the `meta` key holding each pull cursor.
const kSongsCollection = 'songs';
const kPlaylistsCollection = 'playlists';
const kPlaylistsLastSyncKey = 'last_sync_playlists';

class SyncService {
  final FirestoreRestClient fs;
  final SongRepo repo;
  final PlaylistRepo playlists;
  final LocalDb local;
  final _uuid = const Uuid();

  SyncService({
    required this.fs,
    required this.repo,
    required this.playlists,
    required this.local,
  });

  Future<bool> get _online async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> _enqueue(String id, String op, String kind) {
    return repo.enqueue(
      OutboxItem(
        id: _uuid.v4(),
        songId: id,
        op: op,
        kind: kind,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> queueUpsert(Song s) async {
    await repo.upsertSong(
      s.copyWith(
        dirty: true,
        deleted: false,
      ),
    );
    await _enqueue(s.id, 'upsert', OutboxKind.song);
  }

  Future<void> queueDelete(String songId) async {
    await repo.markDeleted(songId);
    await _enqueue(songId, 'delete', OutboxKind.song);
  }

  Future<void> queueUpsertPlaylist(Playlist p) async {
    await playlists.upsertPlaylist(
      p.copyWith(
        dirty: true,
        deleted: false,
      ),
    );
    await _enqueue(p.id, 'upsert', OutboxKind.playlist);
  }

  Future<void> queueDeletePlaylist(String playlistId) async {
    await playlists.markDeleted(playlistId);
    await _enqueue(playlistId, 'delete', OutboxKind.playlist);
  }

  Future<SyncResult> syncNow() async {
    if (!await _online) {
      return const SyncResult(pushed: 0, pulled: 0);
    }

    final pushed = await _pushOutbox();
    final pulled = await _pullSongs() + await _pullPlaylists();

    return SyncResult(pushed: pushed, pulled: pulled);
  }

  /// Drains the outbox in order and stops at the first failure so the
  /// remaining rows are retried next time.
  Future<int> _pushOutbox() async {
    int pushed = 0;
    final outbox = await repo.outbox();

    for (final item in outbox) {
      try {
        final ok = item.kind == OutboxKind.playlist
            ? await _pushPlaylist(item)
            : await _pushSong(item);
        if (ok) pushed++;
        await repo.removeOutbox(item.id);
      } catch (_) {
        break;
      }
    }

    return pushed;
  }

  /// False when the row points at a document that no longer exists locally.
  Future<bool> _pushSong(OutboxItem item) async {
    final song = await repo.getSong(item.songId);
    if (song == null) return false;

    if (item.op == 'upsert') {
      await fs.upsertDoc(
        collection: kSongsCollection,
        docId: song.id,
        fields: song.toServerFields(),
      );
    } else if (item.op == 'delete') {
      try {
        await fs.deleteDoc(collection: kSongsCollection, docId: song.id);
      } catch (_) {}
    }
    await repo.markClean(song.id);
    return true;
  }

  Future<bool> _pushPlaylist(OutboxItem item) async {
    final playlist = await playlists.getPlaylist(item.songId);
    if (playlist == null) return false;

    if (item.op == 'upsert') {
      await fs.upsertDoc(
        collection: kPlaylistsCollection,
        docId: playlist.id,
        fields: playlist.toServerFields(),
      );
    } else if (item.op == 'delete') {
      try {
        await fs.deleteDoc(
          collection: kPlaylistsCollection,
          docId: playlist.id,
        );
      } catch (_) {}
    }
    await playlists.markClean(playlist.id);
    return true;
  }

  static int _ts(Object? v) =>
      v is int ? v : int.tryParse('$v') ?? 0;

  Future<int> _pullSongs() async {
    final lastSync = await local.getLastSync();
    final changes = await fs.getChangesSince(
      collection: kSongsCollection,
      since: lastSync,
    );

    int pulled = 0;
    int maxTs = lastSync;

    for (final c in changes) {
      final id = (c['id'] as String?) ?? '';
      if (id.isEmpty) continue;

      final localSong = await repo.getSong(id);
      if (localSong != null && localSong.dirty) continue;

      final updatedAt = _ts(c['updatedAt']);

      final s = Song(
        id: id,
        title: (c['title'] ?? '') as String,
        artist: (c['artist'] ?? '') as String,
        keyName: (c['keyName'] ?? 'C') as String,
        chordPro: (c['chordPro'] ?? '') as String,
        lyrics: (c['lyrics'] ?? '') as String,
        songType: (c['songType'] ?? '') as String,
        language: (c['language'] ?? '') as String,
        themes: decodeThemes(c['themes'] ?? c['theme']),
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

    return pulled;
  }

  Future<int> _pullPlaylists() async {
    final lastSync = await local.getLastSync(key: kPlaylistsLastSyncKey);
    final changes = await fs.getChangesSince(
      collection: kPlaylistsCollection,
      since: lastSync,
    );

    int pulled = 0;
    int maxTs = lastSync;

    for (final c in changes) {
      final id = (c['id'] as String?) ?? '';
      if (id.isEmpty) continue;

      final localPlaylist = await playlists.getPlaylist(id);
      if (localPlaylist != null && localPlaylist.dirty) continue;

      final updatedAt = _ts(c['updatedAt']);

      final p = Playlist(
        id: id,
        name: (c['name'] ?? '') as String,
        songIds: decodeDelimited(c['songIds']),
        updatedAt: updatedAt,
        dirty: false,
        deleted: (c['deleted'] ?? false) == true,
      );

      await playlists.upsertPlaylist(p);
      pulled++;

      if (updatedAt > maxTs) {
        maxTs = updatedAt;
      }
    }

    if (maxTs != lastSync) {
      await local.setLastSync(maxTs, key: kPlaylistsLastSyncKey);
    }

    return pulled;
  }
}

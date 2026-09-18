import 'local_db.dart';
import 'models.dart';

class PlaylistRepo {
  final LocalDb local;
  PlaylistRepo(this.local);

  Future<List<Playlist>> listPlaylists() async {
    final rows = await local.listPlaylists();
    return rows.map((r) => Playlist.fromDb(r)).toList();
  }

  Future<Playlist?> getPlaylist(String id) async {
    final row = await local.getPlaylist(id);
    if (row == null) return null;
    return Playlist.fromDb(row);
  }

  Future<void> upsertPlaylist(Playlist p) async {
    await local.upsertPlaylist(p.toDb());
  }

  Future<void> markDeleted(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await local.markPlaylistDeleted(id, now);
  }

  Future<void> markClean(String id, {int? updatedAt}) async {
    await local.markPlaylistClean(id, updatedAt: updatedAt);
  }
}

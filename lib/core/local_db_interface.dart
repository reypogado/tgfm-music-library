abstract class LocalDb {
  Future<void> init();

  /// Sync cursors live in the `meta` table, one per collection.
  Future<int> getLastSync({String key = 'last_sync'});
  Future<void> setLastSync(int ts, {String key = 'last_sync'});

  Future<List<Map<String, dynamic>>> listSongs();
  Future<Map<String, dynamic>?> getSong(String id);
  Future<void> upsertSong(Map<String, dynamic> data);
  Future<void> markDeleted(String id, int updatedAt);
  Future<void> markClean(String id, {int? updatedAt});

  Future<List<Map<String, dynamic>>> listPlaylists();
  Future<Map<String, dynamic>?> getPlaylist(String id);
  Future<void> upsertPlaylist(Map<String, dynamic> data);
  Future<void> markPlaylistDeleted(String id, int updatedAt);
  Future<void> markPlaylistClean(String id, {int? updatedAt});

  Future<void> enqueue(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> outbox();
  Future<void> removeOutbox(String id);
}

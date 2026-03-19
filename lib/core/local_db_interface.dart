abstract class LocalDb {
  Future<void> init();

  Future<int> getLastSync();
  Future<void> setLastSync(int ts);

  Future<List<Map<String, dynamic>>> listSongs();
  Future<Map<String, dynamic>?> getSong(String id);
  Future<void> upsertSong(Map<String, dynamic> data);
  Future<void> markDeleted(String id, int updatedAt);
  Future<void> markClean(String id, {int? updatedAt});

  Future<void> enqueue(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> outbox();
  Future<void> removeOutbox(String id);
}
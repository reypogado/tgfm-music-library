import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_rest.dart';
import 'local_db.dart';
import 'models.dart';
import 'song_repo.dart';
import 'sync_service.dart';

const kProjectId = 'tgfm-music-library';

final localDbProvider = Provider<LocalDb>((ref) {
  return createLocalDb();
});

final firestoreRestProvider = Provider((ref) {
  return FirestoreRestClient(projectId: kProjectId);
});

final songRepoProvider = Provider((ref) {
  return SongRepo(ref.watch(localDbProvider));
});

final syncServiceProvider = Provider((ref) {
  return SyncService(
    fs: ref.watch(firestoreRestProvider),
    repo: ref.watch(songRepoProvider),
    local: ref.watch(localDbProvider),
  );
});

final songsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(songRepoProvider).listSongs();
});
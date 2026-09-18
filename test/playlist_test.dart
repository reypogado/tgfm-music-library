import 'package:flutter_test/flutter_test.dart';
import 'package:tgfm_music_library/core/models.dart';

void main() {
  const ids = ['3f1c-aaaa', '9b2e-bbbb', '7d4a-cccc'];

  Playlist make() => const Playlist(
        id: 'p1',
        name: 'Sunday service',
        songIds: ids,
        updatedAt: 42,
        dirty: true,
        deleted: false,
      );

  test('song order survives a database round-trip', () {
    final back = Playlist.fromDb(make().toDb());
    expect(back.songIds, ids);
    expect(back.name, 'Sunday service');
    expect(back.dirty, isTrue);
  });

  test('server fields carry every stored field as plain values', () {
    final f = make().toServerFields();
    expect(f.keys, containsAll(['name', 'songIds', 'updatedAt', 'deleted']));
    expect(decodeDelimited(f['songIds']), ids);
  });

  test('a row without song_ids reads as empty', () {
    final p = Playlist.fromDb({'id': 'p', 'updated_at': 1});
    expect(p.songIds, isEmpty);
    expect(p.name, '');
  });

  test('outbox rows default to the song kind', () {
    final it = OutboxItem.fromDb({
      'id': 'o',
      'song_id': 's',
      'op': 'upsert',
      'created_at': 1,
    });
    expect(it.kind, OutboxKind.song);

    final pl = OutboxItem(
      id: 'o2',
      songId: 'p',
      op: 'delete',
      kind: OutboxKind.playlist,
      createdAt: 2,
    );
    expect(OutboxItem.fromDb(pl.toDb()).kind, OutboxKind.playlist);
  });
}

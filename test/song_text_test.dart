import 'package:flutter_test/flutter_test.dart';
import 'package:tgfm_music_library/core/models.dart';
import 'package:tgfm_music_library/core/song_content.dart';
import 'package:tgfm_music_library/core/song_text.dart';

Song song({
  String title = 'Amazing Grace',
  String artist = '',
  String key = 'G',
  String chordPro = '',
  String lyrics = '',
}) =>
    Song(
      id: 'x',
      title: title,
      artist: artist,
      keyName: key,
      chordPro: chordPro,
      lyrics: lyrics,
      updatedAt: 0,
      dirty: false,
      deleted: false,
    );

void main() {
  group('chordLines', () {
    test('chords-only line is spaced out', () {
      expect(SongText.chordLines('[G#m][-][A][-][B]'), ['G#m - A - B']);
    });

    test('inline chords sit over their lyric column', () {
      expect(
        SongText.chordLines('[G]Amazing [G7]grace how [C]sweet'),
        ['G       G7        C', 'Amazing grace how sweet'],
      );
    });

    test('overlapping chords are pushed right', () {
      expect(
        SongText.chordLines('[Cmaj7][D]go'),
        ['Cmaj7 D', 'go'],
      );
    });

    test('plain lines inside a chord doc pass through', () {
      expect(SongText.chordLines('(repeat)\n[G]'), ['(repeat)', 'G']);
    });
  });

  group('render', () {
    final s = song(
      artist: 'John Newton',
      chordPro: '## Verse\n[G][C][G]\n\n## Chorus\n[D][G]',
      lyrics: '## Verse\nAmazing grace\nhow sweet\n\n## Chorus\nI once was lost',
    );

    test('lyrics view has no chords and no key', () {
      expect(
        SongText.render(s, view: SongView.lyrics),
        'Amazing Grace\nJohn Newton\n\n'
        'Verse:\nAmazing grace\nhow sweet\n\n'
        'Chorus:\nI once was lost',
      );
    });

    test('chords view shows the transposed key and chords', () {
      expect(
        SongText.render(s, view: SongView.chords, transpose: 2),
        'Amazing Grace\nJohn Newton\nKey: A\n\n'
        'Verse:\nA D A\n\n'
        'Chorus:\nE A',
      );
    });

    test('both view stacks chords then lyrics per section', () {
      expect(
        SongText.render(s, view: SongView.both),
        'Amazing Grace\nJohn Newton\nKey: G\n\n'
        'Verse:\nG C G\n\nAmazing grace\nhow sweet\n\n'
        'Chorus:\nD G\n\nI once was lost',
      );
    });

    test('numbers mode rewrites chords relative to the key', () {
      expect(
        SongText.render(s, view: SongView.chords, numbersMode: true),
        contains('Verse:\n1 4 1'),
      );
    });

    test('a "Lyrics" placeholder key is not printed', () {
      final l = song(key: 'Lyrics', chordPro: '## Verse\njust words');
      expect(
        SongText.render(l, view: SongView.lyrics),
        'Amazing Grace\n\nVerse:\njust words',
      );
    });
  });

  group('renderPlaylist', () {
    test('joins songs in order under the playlist name', () {
      final p = Playlist(
        id: 'p',
        name: 'Sunday',
        songIds: const ['a', 'b'],
        updatedAt: 0,
        dirty: false,
        deleted: false,
      );
      final a = song(title: 'A', lyrics: '## Verse\nla');
      final b = song(title: 'B', lyrics: '## Verse\nlo');

      expect(
        SongText.renderPlaylist(p, [a, b], view: SongView.lyrics),
        'Sunday\n======\n\nA\n\nVerse:\nla\n\n---\n\nB\n\nVerse:\nlo',
      );
    });
  });
}

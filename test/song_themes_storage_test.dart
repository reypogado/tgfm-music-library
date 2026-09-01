import 'package:flutter_test/flutter_test.dart';
import 'package:tgfm_music_library/core/models.dart';
import 'package:tgfm_music_library/core/song_taxonomy.dart';

void main() {
  group('theme encoding', () {
    test('round-trips through the delimited string', () {
      const themes = [
        SongTheme.fatherExaltation,
        SongTheme.intimacyPrayer, // contains '/'
        SongTheme.adorationWorship, // contains '&'
        SongTheme.manInnerHealing, // contains '-'
      ];

      expect(decodeThemes(encodeThemes(themes)), themes);
    });

    test('every preset survives the round-trip individually', () {
      for (final t in SongTheme.values) {
        expect(decodeThemes(encodeThemes([t])), [t], reason: t);
      }
    });

    test('empty means no themes', () {
      expect(encodeThemes(const []), '');
      expect(decodeThemes(''), isEmpty);
      expect(decodeThemes(null), isEmpty);
    });

    test('blanks and stray whitespace are dropped', () {
      expect(encodeThemes(const ['  ', 'Faith & Trust', '']), 'Faith & Trust');
      expect(decodeThemes('Holy Spirit |  | Faith & Trust'),
          ['Holy Spirit', 'Faith & Trust']);
    });

    test('the older single-valued field reads as one theme', () {
      expect(decodeThemes('Holy Spirit'), ['Holy Spirit']);
    });

    test('a list from the server is accepted too', () {
      expect(decodeThemes(['Holy Spirit', 'Faith & Trust']),
          ['Holy Spirit', 'Faith & Trust']);
    });
  });

  group('Song storage', () {
    Song withThemes(List<String> themes) => Song(
          id: 'x',
          title: 't',
          artist: '',
          keyName: 'C',
          chordPro: '',
          themes: themes,
          updatedAt: 1,
          dirty: false,
          deleted: false,
        );

    test('survives a database round-trip', () {
      const themes = [SongTheme.holySpirit, SongTheme.missionKingdom];
      final back = Song.fromDb(withThemes(themes).toDb());

      expect(back.themes, themes);
    });

    test('a row written before themes existed reads as none', () {
      final row = withThemes(const []).toDb()..remove('themes');
      expect(Song.fromDb(row).themes, isEmpty);
    });

    test('a v3 row with a single theme still reads', () {
      final row = withThemes(const []).toDb()
        ..remove('themes')
        ..['theme'] = SongTheme.loveOfGod;

      expect(Song.fromDb(row).themes, [SongTheme.loveOfGod]);
    });

    test('the server payload always carries the themes field', () {
      final fields = withThemes(const [SongTheme.faithTrust]).toServerFields();

      // upsertSong PATCHes without an updateMask, so a missing key drops data.
      expect(fields.containsKey('themes'), isTrue);
      expect(fields['themes'], SongTheme.faithTrust);
    });

    test('copyWith replaces the whole theme list', () {
      final s = withThemes(const [SongTheme.holySpirit]);
      expect(s.copyWith(themes: const []).themes, isEmpty);
      expect(
        s.copyWith(themes: const [SongTheme.faithTrust]).themes,
        [SongTheme.faithTrust],
      );
      expect(s.copyWith(title: 'other').themes, [SongTheme.holySpirit]);
    });
  });
}

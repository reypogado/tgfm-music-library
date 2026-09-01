import 'package:flutter_test/flutter_test.dart';
import 'package:tgfm_music_library/core/models.dart';
import 'package:tgfm_music_library/core/song_taxonomy.dart';

Song s(
  String title, {
  String artist = '',
  String keyName = 'C',
  String songType = '',
  String language = '',
  List<String> themes = const [],
  int updatedAt = 0,
}) =>
    Song(
      id: title,
      title: title,
      artist: artist,
      keyName: keyName,
      chordPro: '',
      updatedAt: updatedAt,
      songType: songType,
      language: language,
      themes: themes,
      dirty: false,
      deleted: false,
    );

void main() {
  group('sorting', () {
    final songs = [
      s('Banner', updatedAt: 300),
      s('apple', updatedAt: 100),
      s('Cornerstone', updatedAt: 200),
    ];

    test('title sorts case-insensitively', () {
      expect(
        sortSongs(songs, SongSort.titleAsc).map((e) => e.title),
        ['apple', 'Banner', 'Cornerstone'],
      );
      expect(
        sortSongs(songs, SongSort.titleDesc).map((e) => e.title),
        ['Cornerstone', 'Banner', 'apple'],
      );
    });

    test('recent puts the newest first, oldest reverses it', () {
      expect(
        sortSongs(songs, SongSort.recent).map((e) => e.title),
        ['Banner', 'Cornerstone', 'apple'],
      );
      expect(
        sortSongs(songs, SongSort.oldest).map((e) => e.title),
        ['apple', 'Cornerstone', 'Banner'],
      );
    });

    test('equal timestamps fall back to title, not input order', () {
      final tied = [s('Zion', updatedAt: 5), s('Abide', updatedAt: 5)];
      expect(
        sortSongs(tied, SongSort.recent).map((e) => e.title),
        ['Abide', 'Zion'],
      );
    });

    test('the source list is left untouched', () {
      final original = [...songs];
      sortSongs(songs, SongSort.titleDesc);
      expect(songs, original);
    });
  });

  group('grouping', () {
    test('no grouping yields a single unnamed folder', () {
      final folders = groupSongs(
        [s('B'), s('A')],
        SongGrouping.none,
        SongSort.titleAsc,
      );

      expect(folders.length, 1);
      expect(folders.single.name, '');
      expect(folders.single.songs.map((e) => e.title), ['A', 'B']);
    });

    test('song type folders are alphabetical', () {
      final folders = groupSongs(
        [
          s('a', songType: SongType.worship),
          s('b', songType: SongType.praise),
          s('c', songType: SongType.warfare),
        ],
        SongGrouping.songType,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name), ['Praise', 'Warfare', 'Worship']);
    });

    test('uncategorised songs get their own folder, sorted last', () {
      final folders = groupSongs(
        [
          s('a'),
          s('b', songType: SongType.worship),
          s('c'),
        ],
        SongGrouping.songType,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name), ['Worship', kUncategorized]);
      expect(folders.last.songs.map((e) => e.title), ['a', 'c']);
    });

    test('songs sort inside their folder', () {
      final folders = groupSongs(
        [
          s('Zion', language: SongLanguage.tagalog, updatedAt: 1),
          s('Abide', language: SongLanguage.tagalog, updatedAt: 2),
        ],
        SongGrouping.language,
        SongSort.recent,
      );

      expect(folders.single.songs.map((e) => e.title), ['Abide', 'Zion']);
    });

    test('a missing artist falls into "Unknown artist", sorted last', () {
      final folders = groupSongs(
        [s('a'), s('b', artist: 'Victoria Orenze')],
        SongGrouping.artist,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name), ['Victoria Orenze', 'Unknown artist']);
    });

    test('a non-musical key groups under "No key"', () {
      // Lyrics-only songs in the live data carry keyName: "Lyrics".
      final folders = groupSongs(
        [s('a', keyName: 'Lyrics'), s('b', keyName: 'G')],
        SongGrouping.key,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name), ['G', 'No key']);
    });

    test('whitespace-only categories count as uncategorised', () {
      expect(groupsOf(s('a', songType: '   '), SongGrouping.songType),
          [kUncategorized]);
      expect(groupsOf(s('a'), SongGrouping.theme), [kUncategorized]);
    });

    test('every song lands in exactly one folder', () {
      final songs = [
        s('a', songType: SongType.praise),
        s('b'),
        s('c', songType: SongType.worship),
        s('d', songType: SongType.praise),
      ];

      final folders = groupSongs(songs, SongGrouping.songType, SongSort.titleAsc);
      final placed = folders.expand((f) => f.songs).toList();

      expect(placed.length, songs.length);
      expect(placed.map((e) => e.title).toSet(), {'a', 'b', 'c', 'd'});
    });

    test('every grouping has a label and handles an empty library', () {
      for (final g in SongGrouping.values) {
        expect(groupingLabels[g], isNotNull, reason: '$g');

        final folders = groupSongs([], g, SongSort.titleAsc);
        expect(
          folders.expand((f) => f.songs),
          isEmpty,
          reason: 'empty library should hold no songs under $g',
        );
      }

      for (final so in SongSort.values) {
        expect(sortLabels[so], isNotNull, reason: '$so');
        expect(sortSongs([], so), isEmpty);
      }
    });
  });

  group('themes are multi-valued', () {
    test('a song appears under each of its themes', () {
      final folders = groupSongs(
        [
          s('a', themes: [SongTheme.holySpirit, SongTheme.faithTrust]),
          s('b', themes: [SongTheme.faithTrust]),
        ],
        SongGrouping.theme,
        SongSort.titleAsc,
      );

      expect(
        folders.map((f) => f.name),
        [SongTheme.holySpirit, SongTheme.faithTrust],
      );
      expect(folders[0].songs.map((e) => e.title), ['a']);
      expect(folders[1].songs.map((e) => e.title), ['a', 'b']);
    });

    test('theme folders follow the chart order, not the alphabet', () {
      final folders = groupSongs(
        [
          s('a', themes: [SongTheme.manInnerHealing]),
          s('b', themes: [SongTheme.fatherExaltation]),
          s('c', themes: [SongTheme.holySpirit]),
        ],
        SongGrouping.theme,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name), [
        SongTheme.fatherExaltation,
        SongTheme.holySpirit,
        SongTheme.manInnerHealing,
      ]);
    });

    test('a theme off the chart sorts after the presets, before catch-alls', () {
      final folders = groupSongs(
        [
          s('a', themes: ['Custom Theme']),
          s('b', themes: [SongTheme.holySpirit]),
          s('c'),
        ],
        SongGrouping.theme,
        SongSort.titleAsc,
      );

      expect(folders.map((f) => f.name),
          [SongTheme.holySpirit, 'Custom Theme', kUncategorized]);
    });

    test('every preset theme has a colour', () {
      for (final t in SongTheme.values) {
        expect(SongTheme.colorOf(t), isNotNull, reason: t);
      }
      expect(SongTheme.colorOf('Not A Theme'), isNull);
    });

    test('preset ranks are unique and ordered', () {
      final ranks = SongTheme.values.map(SongTheme.rank).toList();
      expect(ranks, List.generate(SongTheme.values.length, (i) => i));
      expect(SongTheme.rank('Not A Theme'), SongTheme.values.length);
    });
  });
}

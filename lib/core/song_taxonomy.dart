import 'package:flutter/material.dart';

import 'chrodpro.dart';
import 'models.dart';

/// Fixed pick-lists. Everything the library groups by is chosen from these, so
/// browsing never depends on how a value was typed.
class SongType {
  static const praise = 'Praise';
  static const worship = 'Worship';
  static const warfare = 'Warfare';

  static const values = [praise, worship, warfare];
}

class SongLanguage {
  static const tagalog = 'Tagalog';
  static const bisaya = 'Bisaya';
  static const english = 'English';

  static const values = [tagalog, bisaya, english];
}

/// The team's theme list, in the order they use it (Father, then Jesus, then
/// the Spirit, then response). A song may carry several.
///
/// Colours come from the team's own chart and are used as-is in both light and
/// dark mode, always with a dark label, so a theme reads the same everywhere.
class SongTheme {
  static const fatherExaltation = 'Father- Exaltation';
  static const adorationWorship = 'Adoration & Worship';
  static const crossRedemption = 'Jesus- Cross & Redemption';
  static const secondComing = 'Jesus- Second Coming';
  static const holySpirit = 'Holy Spirit';
  static const loveOfGod = 'Love of God';
  static const praiseCelebration = 'Praise & Celebration';
  static const victoryThanksgiving = 'Victory & Thanksgiving';
  static const surrenderCommitment = 'Surrender & Commitment';
  static const intimacyPrayer = 'Intimacy / Prayer / Soaking';
  static const missionKingdom = 'Mission & Kingdom';
  static const faithTrust = 'Faith & Trust';
  static const manIdentity = 'Man- Identity';
  static const manInnerHealing = 'Man- Inner Healing';

  static const values = [
    fatherExaltation,
    adorationWorship,
    crossRedemption,
    secondComing,
    holySpirit,
    loveOfGod,
    praiseCelebration,
    victoryThanksgiving,
    surrenderCommitment,
    intimacyPrayer,
    missionKingdom,
    faithTrust,
    manIdentity,
    manInnerHealing,
  ];

  static const _colors = <String, Color>{
    fatherExaltation: Color(0xFFC98B7A),
    adorationWorship: Color(0xFFF287B8),
    crossRedemption: Color(0xFFA9DCA6),
    secondComing: Color(0xFFC7E6A8),
    holySpirit: Color(0xFFB4D9F2),
    loveOfGod: Color(0xFFF5AFA8),
    praiseCelebration: Color(0xFF7FC8EC),
    victoryThanksgiving: Color(0xFFF9C89B),
    surrenderCommitment: Color(0xFFB4C8DC),
    intimacyPrayer: Color(0xFFEDBEDC),
    missionKingdom: Color(0xFF8F8FD0),
    faithTrust: Color(0xFFF0DF9E),
    manIdentity: Color(0xFFC6C2AE),
    manInnerHealing: Color(0xFFC99C78),
  };

  /// Null for a theme that is not on the list — callers fall back to a neutral
  /// surface colour rather than inventing one.
  static Color? colorOf(String theme) => _colors[theme.trim()];

  /// These pastels are chosen to carry dark text in either brightness.
  static const onColor = Color(0xFF1F1B16);

  /// Preset order, used so theme folders read Father -> Jesus -> Spirit ->
  /// response instead of alphabetically. Unknown themes sort after the presets.
  static int rank(String theme) {
    final i = values.indexOf(theme.trim());
    return i == -1 ? values.length : i;
  }
}

/// Shown for songs that have not been categorised yet. Sorts last so it never
/// buries the folders that are filled in.
const kUncategorized = 'Uncategorized';

enum SongGrouping { none, songType, language, theme, artist, key }

enum SongSort { titleAsc, titleDesc, recent, oldest }

const groupingLabels = {
  SongGrouping.none: 'All songs',
  SongGrouping.songType: 'Song type',
  SongGrouping.language: 'Language',
  SongGrouping.theme: 'Theme',
  SongGrouping.artist: 'Artist',
  SongGrouping.key: 'Key',
};

const sortLabels = {
  SongSort.titleAsc: 'Title A–Z',
  SongSort.titleDesc: 'Title Z–A',
  SongSort.recent: 'Recently updated',
  SongSort.oldest: 'Oldest first',
};

/// The folders a song belongs in under [grouping]. Every grouping yields
/// exactly one folder except themes, where a song appears under each of its
/// themes.
List<String> groupsOf(Song s, SongGrouping grouping) {
  String orElse(String v) => v.trim().isEmpty ? kUncategorized : v.trim();

  return switch (grouping) {
    SongGrouping.none => const [''],
    SongGrouping.songType => [orElse(s.songType)],
    SongGrouping.language => [orElse(s.language)],
    SongGrouping.theme =>
      s.themes.isEmpty ? const [kUncategorized] : s.themes,
    SongGrouping.artist => [
        s.artist.trim().isEmpty ? 'Unknown artist' : s.artist.trim(),
      ],
    SongGrouping.key => [
        ChordPro.isMusicalKey(s.keyName) ? s.keyName.trim() : 'No key',
      ],
  };
}

int _compare(Song a, Song b, SongSort sort) {
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());

  return switch (sort) {
    SongSort.titleAsc => byTitle,
    SongSort.titleDesc => -byTitle,
    // Ties fall back to title so the order never jitters between rebuilds.
    SongSort.recent => b.updatedAt != a.updatedAt
        ? b.updatedAt.compareTo(a.updatedAt)
        : byTitle,
    SongSort.oldest => a.updatedAt != b.updatedAt
        ? a.updatedAt.compareTo(b.updatedAt)
        : byTitle,
  };
}

List<Song> sortSongs(List<Song> songs, SongSort sort) {
  return [...songs]..sort((a, b) => _compare(a, b, sort));
}

class SongFolder {
  final String name;
  final List<Song> songs;

  const SongFolder({required this.name, required this.songs});
}

/// Buckets songs into folders, each internally ordered by [sort]. Folder names
/// are alphabetical — except themes, which keep the team's own order — with the
/// catch-all buckets pushed to the end.
///
/// A song with several themes appears in each of their folders, so the folder
/// counts can add up to more than the library size.
List<SongFolder> groupSongs(
  List<Song> songs,
  SongGrouping grouping,
  SongSort sort,
) {
  if (grouping == SongGrouping.none) {
    return [SongFolder(name: '', songs: sortSongs(songs, sort))];
  }

  final buckets = <String, List<Song>>{};
  for (final s in songs) {
    for (final name in groupsOf(s, grouping)) {
      buckets.putIfAbsent(name, () => []).add(s);
    }
  }

  bool isCatchAll(String n) =>
      n == kUncategorized || n == 'Unknown artist' || n == 'No key';

  final names = buckets.keys.toList()
    ..sort((a, b) {
      if (isCatchAll(a) != isCatchAll(b)) return isCatchAll(a) ? 1 : -1;

      if (grouping == SongGrouping.theme) {
        final byRank = SongTheme.rank(a).compareTo(SongTheme.rank(b));
        if (byRank != 0) return byRank;
      }

      return a.toLowerCase().compareTo(b.toLowerCase());
    });

  return [
    for (final n in names)
      SongFolder(name: n, songs: sortSongs(buckets[n]!, sort)),
  ];
}

/// Themes are stored as one delimited string so the sqflite column and the
/// hand-rolled Firestore encoder both stay plain strings. '|' cannot appear in
/// a theme name (they use '/' and '&').
const kThemeSeparator = '|';

String encodeThemes(List<String> themes) =>
    themes.map((t) => t.trim()).where((t) => t.isNotEmpty).join(kThemeSeparator);

/// Tolerates the older single-valued `theme` field and any stray whitespace.
List<String> decodeThemes(Object? raw) {
  if (raw is List) {
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }
  final s = (raw as String?) ?? '';
  return s
      .split(kThemeSeparator)
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

class Song {
  final String id;        // local uuid (also used as Firestore docId)
  final String title;
  final String artist;
  final String keyName;
  final String chordPro;  // chords only ('## Section' blocks of [C] tokens)
  final String lyrics;    // lyrics only ('## Section' blocks of plain text)
  final String songType;  // Praise | Worship | Warfare, or '' when unset
  final String language;  // Tagalog | Bisaya | English, or '' when unset
  final List<String> themes; // zero or more, see SongTheme.values
  final int updatedAt;    // ms epoch
  final bool dirty;       // pending push
  final bool deleted;     // soft delete locally

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.keyName,
    required this.chordPro,
    this.lyrics = '',
    this.songType = '',
    this.language = '',
    this.themes = const [],
    required this.updatedAt,
    required this.dirty,
    required this.deleted,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? keyName,
    String? chordPro,
    String? lyrics,
    String? songType,
    String? language,
    List<String>? themes,
    int? updatedAt,
    bool? dirty,
    bool? deleted,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      keyName: keyName ?? this.keyName,
      chordPro: chordPro ?? this.chordPro,
      lyrics: lyrics ?? this.lyrics,
      songType: songType ?? this.songType,
      language: language ?? this.language,
      themes: themes ?? this.themes,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'title': title,
        'artist': artist,
        'key_name': keyName,
        'chord_pro': chordPro,
        'lyrics': lyrics,
        'song_type': songType,
        'language': language,
        'themes': encodeThemes(themes),
        'updated_at': updatedAt,
        'dirty': dirty ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  static Song fromDb(Map<String, Object?> m) => Song(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        artist: (m['artist'] as String?) ?? '',
        keyName: (m['key_name'] as String?) ?? 'C',
        chordPro: (m['chord_pro'] as String?) ?? '',
        lyrics: (m['lyrics'] as String?) ?? '',
        songType: (m['song_type'] as String?) ?? '',
        language: (m['language'] as String?) ?? '',
        themes: decodeThemes(m['themes'] ?? m['theme']),
        updatedAt: (m['updated_at'] as int?) ?? 0,
        dirty: ((m['dirty'] as int?) ?? 0) == 1,
        deleted: ((m['deleted'] as int?) ?? 0) == 1,
      );

  Map<String, dynamic> toServerFields() => {
        'title': title,
        'artist': artist,
        'keyName': keyName,
        'chordPro': chordPro,
        'lyrics': lyrics,
        'songType': songType,
        'language': language,
        'themes': encodeThemes(themes),
        'updatedAt': updatedAt,
        'deleted': deleted,
      };
}

class OutboxItem {
  final String id;
  final String songId;
  final String op; // upsert | delete
  final int createdAt;

  const OutboxItem({
    required this.id,
    required this.songId,
    required this.op,
    required this.createdAt,
  });

  Map<String, Object?> toDb() => {
        'id': id,
        'song_id': songId,
        'op': op,
        'created_at': createdAt,
      };

  static OutboxItem fromDb(Map<String, Object?> m) => OutboxItem(
        id: m['id'] as String,
        songId: m['song_id'] as String,
        op: m['op'] as String,
        createdAt: m['created_at'] as int,
      );
}
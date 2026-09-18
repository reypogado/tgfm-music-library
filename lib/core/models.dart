/// Themes are stored as one delimited string so the sqflite column and the
/// hand-rolled Firestore encoder both stay plain strings. '|' cannot appear in
/// a theme name (they use '/' and '&').
const kThemeSeparator = '|';

String encodeThemes(List<String> themes) => encodeDelimited(themes);

/// Tolerates the older single-valued `theme` field and any stray whitespace.
List<String> decodeThemes(Object? raw) => decodeDelimited(raw);

/// The same '|' packing, used for every list a document carries (themes on a
/// song, song ids on a playlist).
String encodeDelimited(List<String> items) =>
    items.map((t) => t.trim()).where((t) => t.isNotEmpty).join(kThemeSeparator);

List<String> decodeDelimited(Object? raw) {
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

/// An ordered set of songs for a service or event, shared with the team the
/// same way songs are. Song ids are kept even if a song is later deleted; the
/// detail screen shows those as missing so they can be removed.
class Playlist {
  final String id;
  final String name;
  final List<String> songIds; // in performance order
  final int updatedAt;
  final bool dirty;
  final bool deleted;

  const Playlist({
    required this.id,
    required this.name,
    this.songIds = const [],
    required this.updatedAt,
    required this.dirty,
    required this.deleted,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    int? updatedAt,
    bool? dirty,
    bool? deleted,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'name': name,
        'song_ids': encodeDelimited(songIds),
        'updated_at': updatedAt,
        'dirty': dirty ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  static Playlist fromDb(Map<String, Object?> m) => Playlist(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        songIds: decodeDelimited(m['song_ids']),
        updatedAt: (m['updated_at'] as int?) ?? 0,
        dirty: ((m['dirty'] as int?) ?? 0) == 1,
        deleted: ((m['deleted'] as int?) ?? 0) == 1,
      );

  Map<String, dynamic> toServerFields() => {
        'name': name,
        'songIds': encodeDelimited(songIds),
        'updatedAt': updatedAt,
        'deleted': deleted,
      };
}

/// What an outbox row refers to. Stored as a string column so the sqflite
/// migration is a plain `ALTER TABLE ... DEFAULT 'song'`.
class OutboxKind {
  static const song = 'song';
  static const playlist = 'playlist';
}

class OutboxItem {
  final String id;
  final String songId; // the song or playlist id, depending on [kind]
  final String op; // upsert | delete
  final String kind; // OutboxKind
  final int createdAt;

  const OutboxItem({
    required this.id,
    required this.songId,
    required this.op,
    this.kind = OutboxKind.song,
    required this.createdAt,
  });

  Map<String, Object?> toDb() => {
        'id': id,
        'song_id': songId,
        'op': op,
        'kind': kind,
        'created_at': createdAt,
      };

  static OutboxItem fromDb(Map<String, Object?> m) => OutboxItem(
        id: m['id'] as String,
        songId: m['song_id'] as String,
        op: m['op'] as String,
        kind: (m['kind'] as String?) ?? OutboxKind.song,
        createdAt: m['created_at'] as int,
      );
}
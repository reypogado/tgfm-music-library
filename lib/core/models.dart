class Song {
  final String id;        // local uuid (also used as Firestore docId)
  final String title;
  final String artist;
  final String keyName;
  final String chordPro;
  final int updatedAt;    // ms epoch
  final bool dirty;       // pending push
  final bool deleted;     // soft delete locally

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.keyName,
    required this.chordPro,
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
        updatedAt: (m['updated_at'] as int?) ?? 0,
        dirty: ((m['dirty'] as int?) ?? 0) == 1,
        deleted: ((m['deleted'] as int?) ?? 0) == 1,
      );

  Map<String, dynamic> toServerFields() => {
        'title': title,
        'artist': artist,
        'keyName': keyName,
        'chordPro': chordPro,
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
import 'models.dart';
import 'sections.dart';

/// What the viewer/editor is currently showing.
enum SongView { chords, lyrics, both }

/// A section paired across both documents, e.g. the "Chorus" chords next to
/// the "Chorus" lyrics.
class MergedSection {
  final String title;
  final String chordBody;
  final String lyricBody;

  const MergedSection({
    required this.title,
    this.chordBody = '',
    this.lyricBody = '',
  });

  bool get hasChords => SongContent.looksLikeChords(chordBody);
  bool get hasLyrics => lyricBody.trim().isNotEmpty;
}

/// Chords and lyrics are two independent documents on a [Song]:
/// [Song.chordPro] holds chords only, [Song.lyrics] holds lyrics only. Both use
/// the same `## Section` serialization.
///
/// Songs written before the split kept everything in [Song.chordPro]. Those are
/// separated on read, section by section, so old data renders correctly without
/// ever being rewritten. The split is only persisted when the user saves.
class SongContent {
  final List<SongSection> chordSections;
  final List<SongSection> lyricSections;
  final List<MergedSection> merged;

  /// True when the song still stores everything in [Song.chordPro].
  final bool legacy;

  const SongContent({
    required this.chordSections,
    required this.lyricSections,
    required this.merged,
    required this.legacy,
  });

  static final RegExp _bracket = RegExp(r'\[[^\]]*\]');

  /// A body counts as chords when it carries at least one `[...]` token.
  static bool looksLikeChords(String body) => _bracket.hasMatch(body);

  bool get hasChords => chordSections.any((s) => looksLikeChords(s.body));

  bool get hasLyrics => lyricSections.any((s) => s.body.trim().isNotEmpty);

  /// The view a song opens in: chords when it has them, lyrics otherwise.
  SongView get defaultView => hasChords ? SongView.chords : SongView.lyrics;

  static SongContent of(Song song) => fromRaw(song.chordPro, song.lyrics);

  static SongContent fromRaw(String chordPro, String lyrics) {
    if (lyrics.trim().isNotEmpty) {
      return _pair(_parse(chordPro), _parse(lyrics));
    }
    return _splitLegacy(_parse(chordPro));
  }

  /// [parseSections] returns nothing when the text has no `## ` header, so keep
  /// unheadered text instead of dropping it.
  static List<SongSection> _parse(String raw) {
    final parsed = parseSections(raw);
    if (parsed.isNotEmpty) return parsed;
    if (raw.trim().isEmpty) return const [];
    return [SongSection(title: 'Verse', body: raw.trimRight())];
  }

  /// Sections repeat ("Verse" twice), so pair the nth "Verse" of one document
  /// with the nth "Verse" of the other.
  static String _key(String title, Map<String, int> seen) {
    final n = (seen[title] ?? 0) + 1;
    seen[title] = n;
    return '$title#$n';
  }

  /// Already-separated song: pair the two documents section by section.
  static SongContent _pair(
    List<SongSection> chordSections,
    List<SongSection> lyricSections,
  ) {
    final lyricBodies = <String, String>{};
    final lyricKeys = <String>[];
    final seen = <String, int>{};

    for (final s in lyricSections) {
      final key = _key(s.title, seen);
      lyricBodies[key] = s.body;
      lyricKeys.add(key);
    }

    final merged = <MergedSection>[];
    final paired = <String>{};
    seen.clear();

    for (final s in chordSections) {
      final key = _key(s.title, seen);
      paired.add(key);

      merged.add(
        MergedSection(
          title: s.title,
          chordBody: s.body,
          lyricBody: lyricBodies[key] ?? '',
        ),
      );
    }

    // Sections the lyrics document has and the chords document does not.
    for (var i = 0; i < lyricSections.length; i++) {
      if (paired.contains(lyricKeys[i])) continue;
      merged.add(
        MergedSection(
          title: lyricSections[i].title,
          lyricBody: lyricSections[i].body,
        ),
      );
    }

    return SongContent(
      chordSections: chordSections,
      lyricSections: lyricSections,
      merged: merged,
      legacy: false,
    );
  }

  /// Pre-split song: route each section to chords or lyrics by its content,
  /// keeping the original section order.
  static SongContent _splitLegacy(List<SongSection> sections) {
    final chordSections = <SongSection>[];
    final lyricSections = <SongSection>[];
    final merged = <MergedSection>[];

    for (final s in sections) {
      // A section holding chord tokens stays whole in the chord document: any
      // lyrics typed inline are still rendered under their chords.
      if (looksLikeChords(s.body)) {
        chordSections.add(s);
        merged.add(MergedSection(title: s.title, chordBody: s.body));
      } else if (s.body.trim().isNotEmpty) {
        lyricSections.add(s);
        merged.add(MergedSection(title: s.title, lyricBody: s.body));
      } else {
        // Empty section: keep the heading so the structure survives a save.
        chordSections.add(s);
        merged.add(MergedSection(title: s.title));
      }
    }

    return SongContent(
      chordSections: chordSections,
      lyricSections: lyricSections,
      merged: merged,
      legacy: true,
    );
  }

  /// Serializes an edited section list back into the two stored documents.
  /// A section blank on both sides is kept as a chord heading so adding a
  /// section and saving before filling it in does not lose it.
  static ({String chordPro, String lyrics}) serialize(
    List<MergedSection> sections,
  ) {
    final chords = <SongSection>[];
    final lyrics = <SongSection>[];

    for (final s in sections) {
      final chordBody = s.chordBody.trimRight();
      final lyricBody = s.lyricBody.trimRight();

      if (chordBody.trim().isNotEmpty) {
        chords.add(SongSection(title: s.title, body: chordBody));
      }
      if (lyricBody.trim().isNotEmpty) {
        lyrics.add(SongSection(title: s.title, body: lyricBody));
      }
      if (chordBody.trim().isEmpty && lyricBody.trim().isEmpty) {
        chords.add(SongSection(title: s.title, body: ''));
      }
    }

    return (
      chordPro: chords.isEmpty ? '' : serializeSections(chords),
      lyrics: lyrics.isEmpty ? '' : serializeSections(lyrics),
    );
  }
}

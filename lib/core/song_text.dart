import 'chord_simplify.dart';
import 'chrodpro.dart';
import 'models.dart';
import 'nashville.dart';
import 'song_content.dart';

/// Plain-text rendering of a song, for the clipboard. Mirrors what the viewer
/// shows so "copy" gives the media team exactly what is on screen: the same
/// view, transposition and number mode, with chords lined up over the lyric
/// they belong to (monospace positions, like the on-screen grid).
class SongText {
  static String render(
    Song song, {
    required SongView view,
    int transpose = 0,
    bool numbersMode = false,
    bool simplify = false,
  }) {
    final content = SongContent.of(song);
    final showChords = view != SongView.lyrics && content.hasChords;

    final header = <String>[
      song.title.trim().isEmpty ? '(Untitled)' : song.title.trim(),
      if (song.artist.trim().isNotEmpty) song.artist.trim(),
      if (showChords && ChordPro.isMusicalKey(song.keyName))
        'Key: ${_transposeKey(song.keyName, transpose)}',
    ];

    final body = renderSections(
      content,
      view: view,
      songKey: song.keyName,
      transpose: transpose,
      numbersMode: numbersMode,
      simplify: simplify,
    );

    if (body.isEmpty) return header.join('\n');
    return '${header.join('\n')}\n\n$body';
  }

  /// One block per song, separated by a rule, in playlist order.
  static String renderPlaylist(
    Playlist playlist,
    List<Song> songs, {
    required SongView view,
  }) {
    final blocks = [
      for (final s in songs) render(s, view: view),
    ];
    final name = playlist.name.trim();
    final heading = name.isEmpty ? '' : '$name\n${'=' * name.length}\n\n';
    return heading + blocks.join('\n\n---\n\n');
  }

  /// The section blocks only, without the title header.
  static String renderSections(
    SongContent content, {
    required SongView view,
    required String songKey,
    int transpose = 0,
    bool numbersMode = false,
    bool simplify = false,
  }) {
    final sections = switch (view) {
      SongView.chords => content.merged.where((s) => s.hasChords),
      SongView.lyrics => content.merged.where((s) => s.hasLyrics),
      SongView.both =>
        content.merged.where((s) => s.hasChords || s.hasLyrics),
    };

    final out = <String>[];

    for (final sec in sections) {
      final lines = <String>['${sec.title}:'];

      if (view != SongView.lyrics && sec.hasChords) {
        var chordBody = ChordPro.transposeChordPro(sec.chordBody, transpose);
        if (numbersMode) {
          chordBody = Nashville.chordProToNumbersOnly(chordBody, songKey);
        }
        lines.addAll(
          simplify ? simplifyChordLines(chordBody) : chordLines(chordBody),
        );
      }

      if (view == SongView.both && sec.hasChords && sec.hasLyrics) {
        lines.add('');
      }

      if (view != SongView.chords && sec.hasLyrics) {
        lines.addAll(_lyricLines(sec.lyricBody));
      }

      out.add(lines.join('\n'));
    }

    return out.join('\n\n');
  }

  static List<String> _lyricLines(String body) {
    return body
        .replaceAll('\r\n', '\n')
        .trimRight()
        .split('\n')
        .map((l) => l.trimRight())
        .toList();
  }

  /// Lays a chord document out as text. A line with chords and lyrics becomes
  /// two lines, chords above at the column of the lyric they sit on (pushed
  /// right by a space when two would overlap). A chords-only line, such as
  /// `[G][-][D]`, becomes `G - D`.
  static List<String> chordLines(String chordBody) {
    final out = <String>[];

    for (final raw in chordBody.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      final parsed = _parseLine(line);

      if (parsed.chords.isEmpty) {
        out.add(parsed.lyrics.trimRight());
        continue;
      }

      if (parsed.lyrics.trim().isEmpty) {
        out.add(parsed.chords.map((c) => c.chord).join(' '));
        continue;
      }

      final chordLine = StringBuffer();
      for (final token in parsed.chords) {
        var left = token.index;
        if (chordLine.isNotEmpty && left < chordLine.length + 1) {
          left = chordLine.length + 1;
        }
        chordLine.write(' ' * (left - chordLine.length));
        chordLine.write(token.chord);
      }

      out.add(chordLine.toString());
      out.add(parsed.lyrics.trimRight());
    }

    // Trailing blank lines carry no information in a paste.
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  static ({String lyrics, List<({String chord, int index})> chords}) _parseLine(
    String line,
  ) {
    final lyrics = StringBuffer();
    final chords = <({String chord, int index})>[];

    int i = 0;
    while (i < line.length) {
      final ch = line[i];

      if (ch == '[') {
        final end = line.indexOf(']', i + 1);
        if (end == -1) {
          lyrics.write(ch);
          i++;
          continue;
        }

        final chord = line.substring(i + 1, end).trim();
        if (chord.isNotEmpty) {
          chords.add((chord: chord, index: lyrics.length));
        }

        i = end + 1;
        continue;
      }

      lyrics.write(ch);
      i++;
    }

    return (lyrics: lyrics.toString(), chords: chords);
  }

  static String _transposeKey(String key, int semitones) {
    if (semitones % 12 == 0) return key;
    final t = ChordPro.transposeChordPro('[$key]', semitones);
    return t.substring(1, t.length - 1);
  }
}

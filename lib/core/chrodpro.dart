class RenderLine {
  final String chords;
  final String lyrics;
  const RenderLine(this.chords, this.lyrics);
}

class ChordPro {
  static List<RenderLine> render(String chordProText) {
    final lines = chordProText.replaceAll('\r\n', '\n').split('\n');
    return lines.map(_renderLine).toList();
  }

  static RenderLine _renderLine(String line) {
    final lyrics = StringBuffer();
    final chords = StringBuffer();
    int col = 0;

    int i = 0;
    while (i < line.length) {
      final ch = line[i];

      if (ch == '[') {
        final end = line.indexOf(']', i + 1);
        if (end == -1) {
          lyrics.write(ch);
          _ensureLen(chords, col + 1);
          col++;
          i++;
          continue;
        }
        final chord = line.substring(i + 1, end).trim();
        if (chord.isNotEmpty) _placeChord(chords, col, chord);
        i = end + 1;
        continue;
      }

      lyrics.write(ch);
      _ensureLen(chords, col + 1);
      col++;
      i++;
    }

    return RenderLine(chords.toString(), lyrics.toString());
  }

  static void _ensureLen(StringBuffer b, int len) {
    if (b.length < len) b.write(' ' * (len - b.length));
  }

  static void _placeChord(StringBuffer b, int col, String chord) {
    _ensureLen(b, col);
    if (b.length == col) {
      b.write(chord);
      return;
    }
    final current = b.toString();
    final before = current.substring(0, col);
    final after = current.substring(col);
    b
      ..clear()
      ..write(before)
      ..write(chord)
      ..write(after);
  }

  static String transposeChordPro(String chordProText, int semitones) {
    if (semitones % 12 == 0) return chordProText;
    final re = RegExp(r'\[([^\]]+)\]');
    return chordProText.replaceAllMapped(re, (m) {
      final raw = (m.group(1) ?? '').trim();
      return '[${_transposeChordSymbol(raw, semitones)}]';
    });
  }

  static String _transposeChordSymbol(String chord, int semitones) {
    if (chord.isEmpty) return chord;
    final parts = chord.split('/');
    final main = _transposeRootInChord(parts[0], semitones, original: chord);
    if (parts.length == 1) return main;
    final bass = _transposeRootInChord(parts[1], semitones, original: chord);
    return '$main/$bass';
  }

  static String _transposeRootInChord(String chordPart, int semitones, {required String original}) {
    final m = RegExp(r'^([A-G])([#b]?)(.*)$').firstMatch(chordPart.trim());
    if (m == null) return chordPart;

    final root = '${m.group(1)}${m.group(2) ?? ''}';
    final rest = m.group(3) ?? '';
    final preferFlat = original.contains('b') && !original.contains('#');
    final t = _transposeNote(root, semitones, preferFlat: preferFlat);
    return '$t$rest';
  }

  static const _sharp = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  static const _flat  = ['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'];

  static int? _noteIndex(String note) {
    final i1 = _sharp.indexOf(note);
    if (i1 != -1) return i1;
    final i2 = _flat.indexOf(note);
    if (i2 != -1) return i2;
    return null;
  }

  static String _transposeNote(String note, int semitones, {required bool preferFlat}) {
    final idx = _noteIndex(note);
    if (idx == null) return note;
    var n = (idx + semitones) % 12;
    if (n < 0) n += 12;
    return preferFlat ? _flat[n] : _sharp[n];
  }
}
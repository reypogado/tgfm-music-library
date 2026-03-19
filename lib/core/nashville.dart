class Nashville {
  static const notes = [
    'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'
  ];

  static const numbers = [
    '1','b2','2','b3','3','4','b5','5','b6','6','b7','7'
  ];

  /// Converts full chordPro text: [C] -> [1]
  static String chordProToNumbersOnly(String chordPro, String key) {
    final re = RegExp(r'\[([^\]]+)\]');

    return chordPro.replaceAllMapped(re, (m) {
      final raw = (m.group(1) ?? '').trim();
      final number = convertChordToNumberOnly(raw, key);
      return '[$number]';
    });
  }

  /// Converts a chord like Am, G/B, Cmaj7 → number only
  static String convertChordToNumberOnly(String chord, String key) {
    if (chord.isEmpty) return chord;

    // Handle slash chords (G/B → use G)
    final main = chord.split('/').first.trim();

    // Extract root
    final m = RegExp(r'^([A-G])([#b]?)(.*)$').firstMatch(main);
    if (m == null) return chord;

    final root = '${m.group(1)}${m.group(2) ?? ''}';

    final rootIndex = _noteIndex(root);
    final keyIndex = _noteIndex(key);

    if (rootIndex == null || keyIndex == null) return chord;

    int interval = rootIndex - keyIndex;
    if (interval < 0) interval += 12;

    // numbers only (no m,7,sus,etc)
    return numbers[interval];
  }

  static int? _noteIndex(String note) {
    final i1 = notes.indexOf(note);
    if (i1 != -1) return i1;

    // flats support
    const flatMap = {
      'Db': 'C#',
      'Eb': 'D#',
      'Gb': 'F#',
      'Ab': 'G#',
      'Bb': 'A#',
    };

    final sharp = flatMap[note];
    if (sharp == null) return null;

    final i2 = notes.indexOf(sharp);
    if (i2 != -1) return i2;

    return null;
  }
}
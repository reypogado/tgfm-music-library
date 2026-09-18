/// The "Simplify" view of a chord document: lyrics stripped, chords listed per
/// line, consecutive duplicates removed and repeated blocks collapsed into
/// `(xN)`. Shared by the chord renderer and the plain-text export.
List<String> simplifyChordLines(String chordPro) {
  final lines = chordPro.replaceAll('\r\n', '\n').split('\n');
  final cleaned = <String>[];

  for (final line in lines) {
    final chords = _extractChords(line);
    if (chords.isEmpty) continue;

    final deduped = _removeConsecutiveDuplicates(chords);
    if (deduped.isNotEmpty) {
      cleaned.add(deduped.join(' '));
    }
  }

  final merged = _mergePairsIfHelpful(cleaned);
  return _collapseRepeatedLines(merged);
}

List<String> _extractChords(String line) {
  final chordRe = RegExp(r'\[([^\]]+)\]');
  return chordRe
      .allMatches(line)
      .map((m) => (m.group(1) ?? '').trim())
      .where((c) => c.isNotEmpty)
      .toList();
}

List<String> _removeConsecutiveDuplicates(List<String> chords) {
  final out = <String>[];

  for (final chord in chords) {
    if (out.isEmpty || out.last != chord) {
      out.add(chord);
    }
  }

  return out;
}

List<String> _mergePairsIfHelpful(List<String> lines) {
  if (lines.length < 2) return lines;

  final merged = <String>[];
  int i = 0;

  while (i < lines.length) {
    if (i + 1 < lines.length) {
      final a = lines[i].trim();
      final b = lines[i + 1].trim();

      final aParts = a.isEmpty ? <String>[] : a.split(RegExp(r'\s+'));
      final bParts = b.isEmpty ? <String>[] : b.split(RegExp(r'\s+'));

      if (aParts.length == 1 && bParts.isNotEmpty) {
        merged.add([a, b].join(' '));
        i += 2;
        continue;
      }
    }

    merged.add(lines[i]);
    i++;
  }

  return merged;
}

List<String> _collapseRepeatedLines(List<String> lines) {
  if (lines.isEmpty) return lines;

  final result = <String>[];
  int i = 0;

  while (i < lines.length) {
    bool found = false;

    // try bigger repeating blocks first
    for (int blockSize = 4; blockSize >= 1; blockSize--) {
      if (i + blockSize * 2 > lines.length) continue;

      final block = lines.sublist(i, i + blockSize);

      int repeatCount = 1;
      int cursor = i + blockSize;

      while (cursor + blockSize <= lines.length) {
        final nextBlock = lines.sublist(cursor, cursor + blockSize);

        bool same = true;
        for (int j = 0; j < blockSize; j++) {
          if (block[j] != nextBlock[j]) {
            same = false;
            break;
          }
        }

        if (!same) break;

        repeatCount++;
        cursor += blockSize;
      }

      if (repeatCount > 1) {
        result.addAll(block);
        result.add('(x$repeatCount)');
        i = cursor;
        found = true;
        break;
      }
    }

    if (!found) {
      result.add(lines[i]);
      i++;
    }
  }

  return result;
}

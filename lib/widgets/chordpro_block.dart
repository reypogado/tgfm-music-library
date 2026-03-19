import 'package:flutter/material.dart';
import 'package:tgfm_music_library/core/chrodpro.dart';

import '../core/nashville.dart';

class ChordProBlock extends StatelessWidget {
  final String chordProText;
  final int transposeSemitones;

  /// When true, show chords only (no lyrics).
  final bool chordsOnly;

  /// When true, show Nashville numbers instead of chord letters.
  /// (Numbers are injected BEFORE render to keep alignment.)
  final bool numbersMode;

  /// The song's original key (e.g. C, G, Bb, F#). Used for numbersMode.
  final String songKey;

  const ChordProBlock({
    super.key,
    required this.chordProText,
    required this.transposeSemitones,
    required this.songKey,
    this.chordsOnly = false,
    this.numbersMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1) transpose first
    final transposed = ChordPro.transposeChordPro(chordProText, transposeSemitones);

    // 2) if numbersMode, convert [Chord] -> [Number] BEFORE rendering (keeps spacing)
    final input = numbersMode
        ? Nashville.chordProToNumbersOnly(transposed, songKey)
        : transposed;

    if (chordsOnly) {
      final chordLines = _extractChordLines(input);

      if (chordLines.isEmpty) {
        return Text(
          '(No chords)',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in chordLines) ...[
            Text(
              line,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    // Normal render (chords aligned above lyrics)
    final lines = ChordPro.render(input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines) ...[
          if (l.chords.trim().isNotEmpty)
            Text(
              l.chords,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            l.lyrics,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Extract chords from chordPro text line-by-line.
  /// If numbersMode is enabled, chords were already converted inside [ ] before this runs.
  ///
  /// Example:
  ///   "[C]I saw the [Am]Lord" -> "C Am"
  ///   "[1]I saw the [6]Lord"  -> "1 6"
  List<String> _extractChordLines(String chordPro) {
    final lines = chordPro.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    final chordRe = RegExp(r'\[([^\]]+)\]');

    for (final line in lines) {
      final matches = chordRe
          .allMatches(line)
          .map((m) => (m.group(1) ?? '').trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (matches.isNotEmpty) {
        out.add(matches.join(' '));
      }
    }

    return out;
  }
}
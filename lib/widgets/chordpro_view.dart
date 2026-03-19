import 'package:flutter/material.dart';
import 'package:tgfm_music_library/core/chrodpro.dart';

class ChordProView extends StatelessWidget {
  final String chordProText;
  final int transposeSemitones;

  const ChordProView({
    super.key,
    required this.chordProText,
    required this.transposeSemitones,
  });

  @override
  Widget build(BuildContext context) {
    final transposed = ChordPro.transposeChordPro(chordProText, transposeSemitones);
    final lines = ChordPro.render(transposed);

    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final l = lines[i];
          final showChords = l.chords.trim().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showChords)
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
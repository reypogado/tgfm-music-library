import 'package:flutter/material.dart';
import 'package:tgfm_music_library/widgets/chordpro_block.dart';

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
    return ChordProBlock(
      chordProText: chordProText,
      transposeSemitones: transposeSemitones,
      songKey: 'C',
    );
  }
}
import 'package:flutter/material.dart';

/// Plain lyrics, no chord positioning. Kept in a proportional face at a
/// comfortable reading size — the monospace grid only matters for chords.
class LyricsBlock extends StatelessWidget {
  final String text;
  final double fontSize;

  const LyricsBlock({super.key, required this.text, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').trimRight().split('\n');

    if (lines.every((l) => l.trim().isEmpty)) {
      return Text(
        '(No lyrics)',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line.trimRight(),
              style: TextStyle(fontSize: fontSize, height: 1.45),
            ),
          ),
      ],
    );
  }
}

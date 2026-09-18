import 'package:flutter/material.dart';
import 'package:tgfm_music_library/core/chrodpro.dart';
import '../core/chord_simplify.dart';
import '../core/nashville.dart';

class _ChordToken {
  final String chord;
  final int lyricIndex;

  const _ChordToken({required this.chord, required this.lyricIndex});
}

class _ParsedLine {
  final String lyrics;
  final List<_ChordToken> chords;

  const _ParsedLine({required this.lyrics, required this.chords});
}

class ChordProBlock extends StatelessWidget {
  final String chordProText;
  final int transposeSemitones;
  final bool chordsOnly;
  final bool numbersMode;
  final String songKey;

  const ChordProBlock({
    super.key,
    required this.chordProText,
    required this.transposeSemitones,
    required this.songKey,
    this.chordsOnly = false,
    this.numbersMode = false,
  });

  TextStyle _getChordStyle() {
  return TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    fontWeight: chordsOnly ? FontWeight.w400 : FontWeight.w700,
    height: 1.2,
  );
}

  static const TextStyle _lyricStyle = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    height: 1.2,
  );

@override
Widget build(BuildContext context) {
  final transposed = ChordPro.transposeChordPro(
    chordProText,
    transposeSemitones,
  );

  final input = numbersMode
      ? Nashville.chordProToNumbersOnly(transposed, songKey)
      : transposed;

  if (chordsOnly) {
    final chordLines = simplifyChordLines(input);

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
            softWrap: true,
            overflow: TextOverflow.visible,
            style: _getChordStyle(),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  final parsedLines = _parseLines(input);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in parsedLines)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MeasuredChordLine(
            line: line,
            chordStyle: _getChordStyle(),
            lyricStyle: _lyricStyle,
          ),
        ),
    ],
  );
}

  List<_ParsedLine> _parseLines(String chordPro) {
    final lines = chordPro.replaceAll('\r\n', '\n').split('\n');
    return lines.map(_parseLine).toList();
  }

  _ParsedLine _parseLine(String line) {
    final lyrics = StringBuffer();
    final chords = <_ChordToken>[];

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
          chords.add(_ChordToken(chord: chord, lyricIndex: lyrics.length));
        }

        i = end + 1;
        continue;
      }

      lyrics.write(ch);
      i++;
    }

    return _ParsedLine(lyrics: lyrics.toString(), chords: chords);
  }
}

class _MeasuredChordLine extends StatelessWidget {
  final _ParsedLine line;
  final TextStyle chordStyle;
  final TextStyle lyricStyle;

  const _MeasuredChordLine({
    required this.line,
    required this.chordStyle,
    required this.lyricStyle,
  });

  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    return painter.width;
  }

  double _measureTextHeight(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    final chordHeight = _measureTextHeight('C', chordStyle);
    final lyricHeight = _measureTextHeight(line.lyrics, lyricStyle);
    final lyricWidth = _measureTextWidth('${line.lyrics} ', lyricStyle);

    const double minGap = 6;

    double previousRight = 0;
    double maxRight = lyricWidth;

    final positioned = <({String chord, double left})>[];

    for (final token in line.chords) {
      final prefix = line.lyrics.substring(0, token.lyricIndex);
      final anchorLeft = _measureTextWidth(prefix, lyricStyle);
      final chordWidth = _measureTextWidth(token.chord, chordStyle);

      double left = anchorLeft;

      if (left < previousRight + minGap) {
        left = previousRight + minGap;
      }

      final right = left + chordWidth;

      positioned.add((chord: token.chord, left: left));

      previousRight = right;
      if (right > maxRight) maxRight = right;
    }

    return SizedBox(
     width: maxRight + 8, 
      height: chordHeight + lyricHeight + 2,
      child: Stack(
        children: [
          for (final item in positioned)
            Positioned(
              left: item.left,
              top: 0,
              child: Text(item.chord, style: chordStyle),
            ),
          Positioned(
            left: 0,
            top: chordHeight + 2,
            child: Text(line.lyrics, style: lyricStyle),
          ),
        ],
      ),
    );
  }
}

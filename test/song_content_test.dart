import 'package:flutter_test/flutter_test.dart';
import 'package:tgfm_music_library/core/models.dart';
import 'package:tgfm_music_library/core/song_content.dart';

Song song({String chordPro = '', String lyrics = ''}) => Song(
      id: 'x',
      title: 't',
      artist: 'a',
      keyName: 'C',
      chordPro: chordPro,
      lyrics: lyrics,
      updatedAt: 0,
      dirty: false,
      deleted: false,
    );

/// Every non-blank source line must survive into one side or the other.
void expectNoLoss(String source, SongContent content) {
  final kept = [
    ...content.chordSections.map((s) => s.body),
    ...content.lyricSections.map((s) => s.body),
  ].join('\n');

  for (final line in source.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('## ')) continue;
    expect(kept, contains(t), reason: 'lost line: $t');
  }
}

void main() {
  group('legacy songs are split on read', () {
    const chordsOnly = '## Verse\n'
        '[G#m][-][A][-][B]\n\n'
        '## Chorus\n'
        '[E][-][C#m][-][B][-][A]';

    const lyricsOnly = '## Verse\n'
        'You are the Pillar that holds my life\n'
        'Master Jesus\n\n'
        '## Chorus\n'
        'Victory has a sound';

    test('a chords-only song reports chords and no lyrics', () {
      final c = SongContent.of(song(chordPro: chordsOnly));

      expect(c.legacy, isTrue);
      expect(c.hasChords, isTrue);
      expect(c.hasLyrics, isFalse);
      expect(c.defaultView, SongView.chords);
      expect(c.chordSections.length, 2);
      expectNoLoss(chordsOnly, c);
    });

    test('a lyrics-only song reports lyrics and no chords', () {
      final c = SongContent.of(song(chordPro: lyricsOnly));

      expect(c.legacy, isTrue);
      expect(c.hasChords, isFalse);
      expect(c.hasLyrics, isTrue);
      expect(c.defaultView, SongView.lyrics);
      expect(c.lyricSections.length, 2);
      expect(
        c.lyricSections.first.body,
        'You are the Pillar that holds my life\nMaster Jesus',
      );
      expectNoLoss(lyricsOnly, c);
    });

    test('a mixed song routes each section by its own content', () {
      const mixed = '## Verse\n'
          'In Your presence I am content\n\n'
          '## Chorus\n'
          '[C][-][G]';

      final c = SongContent.of(song(chordPro: mixed));

      expect(c.hasChords, isTrue);
      expect(c.hasLyrics, isTrue);
      expect(c.lyricSections.single.title, 'Verse');
      expect(c.chordSections.single.title, 'Chorus');
      expect(c.merged.map((s) => s.title), ['Verse', 'Chorus']);
      expectNoLoss(mixed, c);
    });

    test('chords typed inline with lyrics stay together', () {
      const inline = '## Verse\n[C]Amazing gra[Am]ce';
      final c = SongContent.of(song(chordPro: inline));

      expect(c.chordSections.single.body, '[C]Amazing gra[Am]ce');
      expect(c.hasLyrics, isFalse);
      expectNoLoss(inline, c);
    });

    test('text with no section header is kept', () {
      final c = SongContent.of(song(chordPro: 'just some words'));

      expect(c.hasLyrics, isTrue);
      expect(c.lyricSections.single.body, 'just some words');
    });

    test('an empty song has neither side', () {
      final c = SongContent.of(song());

      expect(c.hasChords, isFalse);
      expect(c.hasLyrics, isFalse);
      expect(c.merged, isEmpty);
    });
  });

  group('separated songs', () {
    test('chords and lyrics pair up by section', () {
      final c = SongContent.of(
        song(
          chordPro: '## Verse\n[C][-][G]\n\n## Chorus\n[F][-][C]',
          lyrics: '## Verse\nline one\n\n## Chorus\nline two',
        ),
      );

      expect(c.legacy, isFalse);
      expect(c.hasChords, isTrue);
      expect(c.hasLyrics, isTrue);
      expect(c.merged.length, 2);
      expect(c.merged.first.chordBody, '[C][-][G]');
      expect(c.merged.first.lyricBody, 'line one');
    });

    test('a repeated section title pairs nth with nth', () {
      final c = SongContent.of(
        song(
          chordPro: '## Verse\n[C]\n\n## Verse\n[G]',
          lyrics: '## Verse\nfirst\n\n## Verse\nsecond',
        ),
      );

      expect(c.merged.length, 2);
      expect(c.merged[0].chordBody, '[C]');
      expect(c.merged[0].lyricBody, 'first');
      expect(c.merged[1].chordBody, '[G]');
      expect(c.merged[1].lyricBody, 'second');
    });

    test('a lyrics-only section the chords document lacks is kept', () {
      final c = SongContent.of(
        song(chordPro: '## Verse\n[C]', lyrics: '## Verse\na\n\n## Tag\nb'),
      );

      expect(c.merged.map((s) => s.title), ['Verse', 'Tag']);
      expect(c.merged.last.lyricBody, 'b');
    });
  });

  group('serialize', () {
    test('writes the two documents independently', () {
      final doc = SongContent.serialize(const [
        MergedSection(title: 'Verse', chordBody: '[C][-][G]', lyricBody: 'la'),
        MergedSection(title: 'Chorus', lyricBody: 'only lyrics'),
      ]);

      expect(doc.chordPro, '## Verse\n[C][-][G]');
      expect(doc.lyrics, '## Verse\nla\n\n## Chorus\nonly lyrics');
    });

    test('round-trips through a read without drift', () {
      const sections = [
        MergedSection(title: 'Intro', chordBody: '[C][-][G]'),
        MergedSection(title: 'Verse', chordBody: '[F]', lyricBody: 'a line'),
        MergedSection(title: 'Chorus', lyricBody: 'another line'),
      ];

      final doc = SongContent.serialize(sections);
      final back = SongContent.fromRaw(doc.chordPro, doc.lyrics);

      expect(back.merged.length, sections.length);
      for (var i = 0; i < sections.length; i++) {
        expect(back.merged[i].title, sections[i].title);
        expect(back.merged[i].chordBody, sections[i].chordBody);
        expect(back.merged[i].lyricBody, sections[i].lyricBody);
      }
    });

    test('a section blank on both sides survives as a heading', () {
      final doc = SongContent.serialize(const [
        MergedSection(title: 'Bridge'),
      ]);

      expect(doc.chordPro, '## Bridge');
      expect(SongContent.fromRaw(doc.chordPro, '').merged.single.title,
          'Bridge');
    });

    test('editing a legacy song preserves its content', () {
      const legacy = '## Verse\n'
          'You are the Pillar that holds my life\n\n'
          '## Chorus\n'
          '[C][-][G]';

      final read = SongContent.of(song(chordPro: legacy));
      final doc = SongContent.serialize(read.merged);

      expect(doc.chordPro, '## Chorus\n[C][-][G]');
      expect(doc.lyrics, '## Verse\nYou are the Pillar that holds my life');
      expectNoLoss(legacy, SongContent.fromRaw(doc.chordPro, doc.lyrics));
    });
  });
}

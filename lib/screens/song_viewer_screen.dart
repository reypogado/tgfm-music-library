import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/chrodpro.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/song_content.dart';
import '../widgets/chordpro_block.dart';
import '../widgets/lyrics_block.dart';
import 'song_editor_screen.dart';

// ---- helpers for key label ----
String transposeKeyName(String key, int semitones) {
  if (semitones % 12 == 0) return key;

  const sharp = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  const flat = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  int idx = sharp.indexOf(key);
  if (idx == -1) idx = flat.indexOf(key);
  if (idx == -1) return key;

  var n = (idx + semitones) % 12;
  if (n < 0) n += 12;

  final preferFlat = key.contains('b') && !key.contains('#');
  return preferFlat ? flat[n] : sharp[n];
}

String transposeLabel(int semitones) {
  if (semitones == 0) return 'Original';
  return semitones > 0 ? '+$semitones' : '$semitones';
}

class SongViewerScreen extends ConsumerStatefulWidget {
  final String songId;
  const SongViewerScreen({super.key, required this.songId});

  @override
  ConsumerState<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends ConsumerState<SongViewerScreen> {
  int _transpose = 0;
  bool _simplify = false;
  bool _numbersMode = false;

  /// Null until the song loads, then the song's own default view. Once the user
  /// picks a view it sticks, even across a reload after editing.
  SongView? _view;

  SongView _resolveView(SongContent content) {
    final available = _availableViews(content);
    final current = _view;
    if (current != null && available.contains(current)) return current;
    return content.defaultView;
  }

  List<SongView> _availableViews(SongContent content) {
    if (content.hasChords && content.hasLyrics) {
      return const [SongView.chords, SongView.lyrics, SongView.both];
    }
    if (content.hasChords) return const [SongView.chords];
    if (content.hasLyrics) return const [SongView.lyrics];
    return const [SongView.chords];
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(songRepoProvider);

    return FutureBuilder<Song?>(
      future: repo.getSong(widget.songId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final song = snap.data!;
        final content = SongContent.of(song);
        final view = _resolveView(content);
        final available = _availableViews(content);

        final showChords = view != SongView.lyrics;
        final hasKey = content.hasChords && ChordPro.isMusicalKey(song.keyName);
        final newKey = transposeKeyName(song.keyName, _transpose);

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title.isEmpty ? '(Untitled)' : song.title),
            actions: [
              if (showChords) ...[
                IconButton(
                  tooltip: _numbersMode ? 'Show letters' : 'Show numbers',
                  icon: Icon(_numbersMode ? Icons.looks_one : Icons.music_note),
                  onPressed: () =>
                      setState(() => _numbersMode = !_numbersMode),
                ),
                if (view == SongView.chords)
                  IconButton(
                    tooltip: _simplify ? 'Show full chart' : 'Simplify chords',
                    icon: Icon(_simplify ? Icons.subject : Icons.filter_alt),
                    onPressed: () => setState(() => _simplify = !_simplify),
                  ),
              ],
              if (song.dirty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(child: Text('Pending')),
                ),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () async {
                  await ref.read(syncServiceProvider).syncNow();
                  ref.invalidate(songsProvider);
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongEditorScreen(existingId: song.id),
                    ),
                  );
                  ref.invalidate(songsProvider);
                  setState(() {});
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Material(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    children: [
                      if (available.length > 1)
                        _ViewSelector(
                          value: view,
                          available: available,
                          onChanged: (v) => setState(() => _view = v),
                        ),
                      if (available.length > 1 && hasKey)
                        const SizedBox(height: 10),
                      if (hasKey)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Key: ${song.keyName} → $newKey '
                                '(${transposeLabel(_transpose)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _SongBody(
                  content: content,
                  view: view,
                  songKey: song.keyName,
                  transpose: _transpose,
                  simplify: _simplify && view == SongView.chords,
                  numbersMode: _numbersMode,
                ),
              ),

              if (showChords && hasKey)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _transpose.toDouble(),
                          min: -11,
                          max: 11,
                          divisions: 22,
                          label: transposeLabel(_transpose),
                          onChanged: (v) =>
                              setState(() => _transpose = v.round()),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _transpose = 0),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ViewSelector extends StatelessWidget {
  final SongView value;
  final List<SongView> available;
  final ValueChanged<SongView> onChanged;

  const _ViewSelector({
    required this.value,
    required this.available,
    required this.onChanged,
  });

  static const _labels = {
    SongView.chords: 'Chords',
    SongView.lyrics: 'Lyrics',
    SongView.both: 'Both',
  };

  static const _icons = {
    SongView.chords: Icons.music_note,
    SongView.lyrics: Icons.lyrics_outlined,
    SongView.both: Icons.view_agenda_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<SongView>(
        segments: [
          for (final v in available)
            ButtonSegment(
              value: v,
              label: Text(_labels[v]!),
              icon: Icon(_icons[v], size: 18),
            ),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _SongBody extends StatelessWidget {
  final SongContent content;
  final SongView view;
  final String songKey;
  final int transpose;
  final bool simplify;
  final bool numbersMode;

  const _SongBody({
    required this.content,
    required this.view,
    required this.songKey,
    required this.transpose,
    required this.simplify,
    required this.numbersMode,
  });

  @override
  Widget build(BuildContext context) {
    final sections = switch (view) {
      SongView.chords =>
        content.merged.where((s) => s.hasChords).toList(),
      SongView.lyrics =>
        content.merged.where((s) => s.hasLyrics).toList(),
      SongView.both =>
        content.merged.where((s) => s.hasChords || s.hasLyrics).toList(),
    };

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            view == SongView.lyrics
                ? 'No lyrics for this song yet.'
                : 'No chords for this song yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final sec = sections[i];

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${sec.title}:', style: titleStyle),
              const SizedBox(height: 8),
              if (view != SongView.lyrics && sec.hasChords)
                ChordProBlock(
                  chordProText: sec.chordBody,
                  transposeSemitones: transpose,
                  chordsOnly: simplify,
                  numbersMode: numbersMode,
                  songKey: songKey,
                ),
              if (view == SongView.both && sec.hasChords && sec.hasLyrics)
                const SizedBox(height: 10),
              if (view != SongView.chords && sec.hasLyrics)
                LyricsBlock(text: sec.lyricBody),
            ],
          ),
        );
      },
    );
  }
}

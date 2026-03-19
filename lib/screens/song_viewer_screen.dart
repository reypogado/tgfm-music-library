import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/sections.dart';
import '../widgets/chordpro_block.dart';
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(songRepoProvider);

    return FutureBuilder(
      future: repo.getSong(widget.songId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final song = snap.data!;
        final newKey = transposeKeyName(song.keyName, _transpose);
        final sections = parseSections(song.chordPro);

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title.isEmpty ? '(Untitled)' : song.title),
            actions: [
              IconButton(
                tooltip: _numbersMode ? "Show letters" : "Show numbers",
                icon: Icon(_numbersMode ? Icons.looks_one : Icons.music_note),
                onPressed: () {
                  setState(() {
                    _numbersMode = !_numbersMode;
                  });
                },
              ),
              IconButton(
                tooltip: _simplify ? 'Show lyrics' : 'Simplify (chords only)',
                icon: Icon(_simplify ? Icons.subject : Icons.filter_alt),
                onPressed: () => setState(() => _simplify = !_simplify),
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Key: ${song.keyName} → $newKey (${transposeLabel(_transpose)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: sections.length,
                  itemBuilder: (context, i) {
                    final sec = sections[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sec.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ChordProBlock(
                            chordProText: sec.body,
                            transposeSemitones: _transpose,
                            chordsOnly: _simplify,
                            numbersMode: _numbersMode,
                            songKey: song.keyName,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../core/sections.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  final String? existingId;
  const SongEditorScreen({super.key, this.existingId});

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _EditableSection {
  final String id;
  String title;
  final TextEditingController controller;

  _EditableSection({
    required this.id,
    required this.title,
    required String body,
  }) : controller = TextEditingController(text: body);

  factory _EditableSection.fromSongSection(SongSection s) {
    return _EditableSection(
      id: const Uuid().v4(),
      title: s.title,
      body: s.body,
    );
  }

  SongSection toSongSection() =>
      SongSection(title: title, body: controller.text);

  void dispose() {
    controller.dispose();
  }
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _key = TextEditingController(text: 'C');

  Song? _existing;
  bool _loading = true;
  bool _saving = false;

  final List<_EditableSection> _sections = [];

  static const _presets = <String>[
    'Intro',
    'Verse',
    'Verse 2',
    'Verse 3',
    'Pre-Chorus',
    'Post-Chorus',
    'Chorus',
    'Chorus 2'
    'Chorus 3',
    'Bridge',
    'Bridge 2',
    'Bridge 3',
    'Tag',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.existingId != null) {
      _existing = await ref.read(songRepoProvider).getSong(widget.existingId!);
      if (_existing != null) {
        _title.text = _existing!.title;
        _artist.text = _existing!.artist;
        _key.text = _existing!.keyName;

        final parsed = parseSections(_existing!.chordPro);
        _replaceSections(parsed);
      }
    } else {
      _replaceSections(const [
        SongSection(title: 'Intro', body: ''),
        SongSection(
          title: 'Verse',
          body: '[C]Your lyrics...\n[G]Chords in [brackets]',
        ),
        SongSection(title: 'Chorus', body: ''),
      ]);
    }

    if (_sections.isEmpty) {
      _sections.add(
        _EditableSection(id: const Uuid().v4(), title: 'Verse 1', body: ''),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _replaceSections(List<SongSection> sections) {
    for (final s in _sections) {
      s.dispose();
    }
    _sections
      ..clear()
      ..addAll(sections.map(_EditableSection.fromSongSection));
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _key.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sync = ref.read(syncServiceProvider);

      final title = _title.text.trim();
      final artist = _artist.text.trim();
      final keyName = _key.text.trim().isEmpty ? 'C' : _key.text.trim();

      final chordPro = serializeSections(
        _sections.map((e) => e.toSongSection()).toList(),
      );

      if (_existing == null) {
        final s = Song(
          id: const Uuid().v4(),
          title: title,
          artist: artist,
          keyName: keyName,
          chordPro: chordPro,
          updatedAt: now,
          dirty: true,
          deleted: false,
        );
        await sync.queueUpsert(s);
      } else {
        final s = _existing!.copyWith(
          title: title,
          artist: artist,
          keyName: keyName,
          chordPro: chordPro,
          updatedAt: now,
          dirty: true,
          deleted: false,
        );
        await sync.queueUpsert(s);
      }

      await sync.syncNow();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final item = _sections.removeAt(i);
      _sections.insert(i - 1, item);
    });
  }

  void _moveDown(int i) {
    if (i >= _sections.length - 1) return;
    setState(() {
      final item = _sections.removeAt(i);
      _sections.insert(i + 1, item);
    });
  }

  void _remove(int i) {
    setState(() {
      final removed = _sections.removeAt(i);
      removed.dispose();

      if (_sections.isEmpty) {
        _sections.add(
          _EditableSection(id: const Uuid().v4(), title: 'Verse 1', body: ''),
        );
      }
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(
        _EditableSection(id: const Uuid().v4(), title: 'Verse', body: ''),
      );
    });
  }

  void _appendChord(int i, String chord) {
    final controller = _sections[i].controller;
    final cur = controller.text;
    controller.text = cur.isEmpty ? '[$chord]' : '$cur[$chord]';
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingId == null ? 'Add Song' : 'Edit Song'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _artist,
            decoration: const InputDecoration(
              labelText: 'Artist',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: const InputDecoration(
              labelText: 'Key (C, G, Bb, F#...)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sections',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_sections.length, (i) {
            final sec = _sections[i];

            return Padding(
              key: ValueKey(sec.id),
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _presets.contains(sec.title)
                                  ? sec.title
                                  : 'Verse',
                              items: _presets
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  sec.title = v;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: i == 0 ? null : () => _moveUp(i),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: i == _sections.length - 1
                                ? null
                                : () => _moveDown(i),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => _remove(i),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: sec.controller,
                        minLines: 6,
                        maxLines: 14,
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          labelText: 'Lyrics + chords ([C] format)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),

                      /*
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in const [
                            'C', 'Dm', 'Em', 'F', 'G', 'Am', 'G/B', 'C/E'
                          ])
                            ActionChip(
                              label: Text(c),
                              onPressed: () => _appendChord(i, c),
                            ),
                        ],
                      ),
                      */
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

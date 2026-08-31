import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../core/song_content.dart';
import '../core/song_taxonomy.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  final String? existingId;
  const SongEditorScreen({super.key, this.existingId});

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

/// One section, holding the chords and the lyrics separately. The section list
/// (titles and order) is shared: switching the editor between Chords and
/// Lyrics swaps which body every card is editing.
class _EditableSection {
  final String id;
  String title;
  final TextEditingController chords;
  final TextEditingController lyrics;

  _EditableSection({
    required this.id,
    required this.title,
    String chordBody = '',
    String lyricBody = '',
  })  : chords = TextEditingController(text: chordBody),
        lyrics = TextEditingController(text: lyricBody);

  factory _EditableSection.fromMerged(MergedSection s) => _EditableSection(
        id: const Uuid().v4(),
        title: s.title,
        chordBody: s.chordBody,
        lyricBody: s.lyricBody,
      );

  TextEditingController controllerFor(SongView view) =>
      view == SongView.lyrics ? lyrics : chords;

  MergedSection toMerged() => MergedSection(
        title: title,
        chordBody: chords.text,
        lyricBody: lyrics.text,
      );

  void dispose() {
    chords.dispose();
    lyrics.dispose();
  }
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _key = TextEditingController(text: 'C');

  Song? _existing;
  bool _loading = true;
  bool _saving = false;

  // Empty means "not categorised" — the library files those under
  // "Uncategorized" rather than guessing.
  String _songType = '';
  String _language = '';
  String _theme = '';

  /// Chords or lyrics — `both` is a viewer-only mode.
  SongView _mode = SongView.chords;

  final List<_EditableSection> _sections = [];

  static const _presets = <String>[
    'Intro',
    'Verse',
    'Verse 2',
    'Verse 3',
    'Pre-Chorus',
    'Post-Chorus',
    'Chorus',
    'Chorus 2',
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
        _songType = _existing!.songType;
        _language = _existing!.language;
        _theme = _existing!.theme;

        final content = SongContent.of(_existing!);
        _replaceSections(content.merged);

        // Open on whichever side the song already has.
        _mode = content.defaultView == SongView.lyrics
            ? SongView.lyrics
            : SongView.chords;
      }
    } else {
      _replaceSections(const [
        MergedSection(title: 'Intro'),
        MergedSection(title: 'Verse'),
        MergedSection(title: 'Chorus'),
      ]);
    }

    if (_sections.isEmpty) {
      _sections.add(_EditableSection(id: const Uuid().v4(), title: 'Verse'));
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _replaceSections(List<MergedSection> sections) {
    for (final s in _sections) {
      s.dispose();
    }
    _sections
      ..clear()
      ..addAll(sections.map(_EditableSection.fromMerged));
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

      final doc = SongContent.serialize(
        _sections.map((e) => e.toMerged()).toList(),
      );

      final s = _existing == null
          ? Song(
              id: const Uuid().v4(),
              title: title,
              artist: artist,
              keyName: keyName,
              chordPro: doc.chordPro,
              lyrics: doc.lyrics,
              songType: _songType,
              language: _language,
              theme: _theme,
              updatedAt: now,
              dirty: true,
              deleted: false,
            )
          : _existing!.copyWith(
              title: title,
              artist: artist,
              keyName: keyName,
              chordPro: doc.chordPro,
              lyrics: doc.lyrics,
              songType: _songType,
              language: _language,
              theme: _theme,
              updatedAt: now,
              dirty: true,
              deleted: false,
            );

      await sync.queueUpsert(s);
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

  Future<void> _remove(int i) async {
    final sec = _sections[i];

    // Removing a card drops the chords *and* the lyrics, so confirm when the
    // other side has content the user cannot currently see.
    final hidden = _mode == SongView.lyrics ? sec.chords.text : sec.lyrics.text;
    if (hidden.trim().isNotEmpty) {
      final otherLabel = _mode == SongView.lyrics ? 'chords' : 'lyrics';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove ${sec.title}?'),
          content: Text(
            'This section also has $otherLabel. Removing it deletes both.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _sections.removeAt(i).dispose();

      if (_sections.isEmpty) {
        _sections.add(_EditableSection(id: const Uuid().v4(), title: 'Verse'));
      }
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(_EditableSection(id: const Uuid().v4(), title: 'Verse'));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final editingLyrics = _mode == SongView.lyrics;

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
              helperText: 'Used for transposing the chords.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Categories',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Used to group the library. Tap to set, tap again to clear.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          _ChipPicker(
            label: 'Song type',
            options: SongType.values,
            selected: _songType,
            onChanged: (v) => setState(() => _songType = v),
          ),
          const SizedBox(height: 12),
          _ChipPicker(
            label: 'Language',
            options: SongLanguage.values,
            selected: _language,
            onChanged: (v) => setState(() => _language = v),
          ),
          const SizedBox(height: 12),
          _ChipPicker(
            label: 'Theme',
            options: SongTheme.values,
            selected: _theme,
            onChanged: (v) => setState(() => _theme = v),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SongView>(
              segments: const [
                ButtonSegment(
                  value: SongView.chords,
                  label: Text('Chords'),
                  icon: Icon(Icons.music_note, size: 18),
                ),
                ButtonSegment(
                  value: SongView.lyrics,
                  label: Text('Lyrics'),
                  icon: Icon(Icons.lyrics_outlined, size: 18),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            editingLyrics
                ? 'Typing lyrics. Chords are kept separately — switch above.'
                : 'Typing chords only, e.g. [G][-][A][-][B]. '
                    'Lyrics are kept separately.',
            style: Theme.of(context).textTheme.bodySmall,
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
            final other =
                editingLyrics ? sec.chords.text : sec.lyrics.text;

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
                                setState(() => sec.title = v);
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
                        controller: sec.controllerFor(_mode),
                        minLines: 6,
                        maxLines: 14,
                        style: TextStyle(
                          fontFamily: editingLyrics ? null : 'RobotoMono',
                        ),
                        decoration: InputDecoration(
                          labelText: editingLyrics
                              ? 'Lyrics'
                              : 'Chords ([G] format)',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (other.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                editingLyrics
                                    ? Icons.music_note
                                    : Icons.lyrics_outlined,
                                size: 14,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                editingLyrics
                                    ? 'Also has chords'
                                    : 'Also has lyrics',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
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

/// A one-of-N picker made of chips, so categorising a song is all tapping.
/// Tapping the selected chip clears it back to "uncategorised".
class _ChipPicker extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChipPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // A value saved before it was on the list still shows, and stays selectable.
    final all = [
      ...options,
      if (selected.isNotEmpty && !options.contains(selected)) selected,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in all)
              FilterChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (isOn) => onChanged(isOn ? o : ''),
              ),
          ],
        ),
      ],
    );
  }
}


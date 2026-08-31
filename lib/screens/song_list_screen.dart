import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tgfm_music_library/core/models.dart';

import '../core/chrodpro.dart';
import '../core/providers.dart';
import '../core/settings.dart';
import '../core/song_content.dart';
import '../core/song_taxonomy.dart';
import 'song_editor_screen.dart';
import 'song_viewer_screen.dart';

/// Songs are kept in one library but can be narrowed to the ones that have
/// chords or the ones that have lyrics.
enum _LibraryFilter { all, chords, lyrics }

const _filterLabels = {
  _LibraryFilter.all: 'All',
  _LibraryFilter.chords: 'Chords',
  _LibraryFilter.lyrics: 'Lyrics',
};

class SongListScreen extends ConsumerStatefulWidget {
  const SongListScreen({super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  bool _syncing = false;
  String? _syncMsg;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _LibraryFilter _filter = _LibraryFilter.all;

  SongGrouping _grouping = SongGrouping.none;
  SongSort _sort = SongSort.titleAsc;

  /// Folders the user has collapsed. Everything starts open so the whole
  /// library is one scroll.
  final Set<String> _collapsed = {};

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncMsg = null;
    });
    try {
      final r = await ref.read(syncServiceProvider).syncNow();
      ref.invalidate(songsProvider);
      setState(() => _syncMsg = 'Synced: pushed ${r.pushed}, pulled ${r.pulled}');
    } catch (e) {
      setState(() => _syncMsg = 'Sync error: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_sync);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(SongContent content) {
    return switch (_filter) {
      _LibraryFilter.all => true,
      _LibraryFilter.chords => content.hasChords,
      _LibraryFilter.lyrics => content.hasLyrics,
    };
  }

  bool _matchesQuery(Song s, SongContent content) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;

    if (s.title.toLowerCase().contains(q)) return true;
    if (s.artist.toLowerCase().contains(q)) return true;
    if (s.songType.toLowerCase().contains(q)) return true;
    if (s.language.toLowerCase().contains(q)) return true;
    if (s.theme.toLowerCase().contains(q)) return true;
    if (content.hasChords && s.keyName.toLowerCase().contains(q)) return true;

    // Let people find a song by a line they remember.
    return content.lyricSections
        .any((sec) => sec.body.toLowerCase().contains(q));
  }

  List<Song> _visibleSongs(List<Song> songs) {
    return songs.where((s) {
      final content = SongContent.of(s);
      return _matchesFilter(content) && _matchesQuery(s, content);
    }).toList();
  }

  String _subtitleFor(Song s, SongContent content) {
    final parts = <String>[];
    if (s.artist.trim().isNotEmpty) parts.add(s.artist.trim());
    if (content.hasChords && ChordPro.isMusicalKey(s.keyName)) {
      parts.add('Key: ${s.keyName}');
    }
    // Whichever category is not already the folder heading is worth showing.
    if (_grouping != SongGrouping.songType && s.songType.isNotEmpty) {
      parts.add(s.songType);
    }
    if (_grouping != SongGrouping.language && s.language.isNotEmpty) {
      parts.add(s.language);
    }
    if (_grouping != SongGrouping.theme && s.theme.isNotEmpty) {
      parts.add(s.theme);
    }
    if (s.dirty) parts.add('Pending sync');
    return parts.join(' • ');
  }

  String _emptyMessage(bool libraryEmpty) {
    if (libraryEmpty) {
      return 'No songs yet.\n\nAdd one, then type its chords and its lyrics '
          'on separate tabs.';
    }
    if (_query.isNotEmpty) return 'No songs found for "$_query"';

    return switch (_filter) {
      _LibraryFilter.chords => 'No songs with chords yet.',
      _LibraryFilter.lyrics => 'No songs with lyrics yet.',
      _LibraryFilter.all => 'No songs found.',
    };
  }

  Future<void> _pickGrouping() async {
    final picked = await showModalBottomSheet<SongGrouping>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PickerSheet(
        title: 'Group by',
        options: [
          for (final g in SongGrouping.values)
            (value: g, label: groupingLabels[g]!, icon: _groupingIcons[g]!),
        ],
        selected: _grouping,
      ),
    );

    if (picked != null) {
      setState(() {
        _grouping = picked;
        _collapsed.clear();
      });
    }
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<SongSort>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PickerSheet(
        title: 'Sort by',
        options: [
          for (final s in SongSort.values)
            (value: s, label: sortLabels[s]!, icon: _sortIcons[s]!),
        ],
        selected: _sort,
      ),
    );

    if (picked != null) setState(() => _sort = picked);
  }

  static const _groupingIcons = {
    SongGrouping.none: Icons.list,
    SongGrouping.songType: Icons.category_outlined,
    SongGrouping.language: Icons.translate,
    SongGrouping.theme: Icons.local_offer_outlined,
    SongGrouping.artist: Icons.person_outline,
    SongGrouping.key: Icons.piano_outlined,
  };

  static const _sortIcons = {
    SongSort.titleAsc: Icons.sort_by_alpha,
    SongSort.titleDesc: Icons.sort_by_alpha,
    SongSort.recent: Icons.schedule,
    SongSort.oldest: Icons.history,
  };

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: [
          IconButton(
            tooltip: themeModeLabels[themeMode],
            icon: Icon(themeModeIcons[themeMode]),
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
          IconButton(
            tooltip: 'Sync',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SongEditorScreen()),
          );
          ref.invalidate(songsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
      ),
      body: Column(
        children: [
          if (_syncMsg != null)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text(_syncMsg!)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _syncMsg = null),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search songs, artist, lyrics...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Everything below is tap-only: content filter, then group and sort.
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _LibraryFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabels[f]!),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: _groupingIcons[_grouping]!,
                    label: groupingLabels[_grouping]!,
                    onPressed: _pickGrouping,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerButton(
                    icon: _sortIcons[_sort]!,
                    label: sortLabels[_sort]!,
                    onPressed: _pickSort,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (songs) {
                final visible = _visibleSongs(songs);

                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage(songs.isEmpty),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final folders = groupSongs(visible, _grouping, _sort);

                return RefreshIndicator(
                  onRefresh: _sync,
                  child: ListView(
                    children: [
                      for (final folder in folders)
                        ..._buildFolder(folder),
                      const SizedBox(height: 88), // clears the FAB
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFolder(SongFolder folder) {
    if (_grouping == SongGrouping.none) {
      return [
        for (final s in folder.songs) _songTile(s),
      ];
    }

    final open = !_collapsed.contains(folder.name);

    return [
      _FolderHeader(
        name: folder.name,
        count: folder.songs.length,
        open: open,
        onTap: () => setState(() {
          if (open) {
            _collapsed.add(folder.name);
          } else {
            _collapsed.remove(folder.name);
          }
        }),
      ),
      if (open)
        for (final s in folder.songs) _songTile(s, indented: true),
    ];
  }

  Widget _songTile(Song s, {bool indented = false}) {
    final content = SongContent.of(s);

    return ListTile(
      key: ValueKey(s.id),
      contentPadding: EdgeInsets.only(left: indented ? 28 : 16, right: 8),
      title: Text(s.title.isEmpty ? '(Untitled)' : s.title),
      subtitle: Text(_subtitleFor(s, content)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ContentBadge(content: content),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SongViewerScreen(songId: s.id)),
        );
        ref.invalidate(songsProvider);
      },
      onLongPress: () => _showSongActions(s),
    );
  }

  Future<void> _showSongActions(Song s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SongEditorScreen(existingId: s.id)),
      );
      ref.invalidate(songsProvider);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text('Delete "${s.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(syncServiceProvider).queueDelete(s.id);
      ref.invalidate(songsProvider);
    }
  }
}

/// A compact button that opens a picker sheet and shows the current choice.
class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

/// Generic tap-to-choose sheet, shared by the group and sort pickers.
class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<({T value, String label, IconData icon})> options;
  final T selected;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // Scrolls rather than overflowing on short screens / landscape.
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    leading: Icon(o.icon),
                    title: Text(o.label),
                    trailing:
                        o.value == selected ? const Icon(Icons.check) : null,
                    selected: o.value == selected,
                    onTap: () => Navigator.pop(context, o.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tappable folder heading with a song count.
class _FolderHeader extends StatelessWidget {
  final String name;
  final int count;
  final bool open;
  final VoidCallback onTap;

  const _FolderHeader({
    required this.name,
    required this.count,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(
                open ? Icons.folder_open : Icons.folder,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$count', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 4),
              Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows at a glance whether a song carries chords, lyrics, or both.
class _ContentBadge extends StatelessWidget {
  final SongContent content;

  const _ContentBadge({required this.content});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.hasChords)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(Icons.music_note, size: 16, color: color),
          ),
        if (content.hasLyrics)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(Icons.lyrics_outlined, size: 16, color: color),
          ),
      ],
    );
  }
}

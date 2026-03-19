import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tgfm_music_library/core/models.dart';

import '../core/providers.dart';
import 'song_editor_screen.dart';
import 'song_viewer_screen.dart';

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

  List<Song> _filterSongs(List<Song> songs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return songs;

    return songs.where((s) {
      final title = s.title.toLowerCase();
      final artist = s.artist.toLowerCase();
      final key = s.keyName.toLowerCase();

      return title.contains(q) || artist.contains(q) || key.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: [
          IconButton(
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
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Search songs, artist...',
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

          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (songs) {
                final filteredSongs = _filterSongs(songs);

                if (filteredSongs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'No songs yet.\n\nUse ChordPro format:\n[C]Amazing gra[Am]ce\n[F]...'
                            : 'No songs found for "$_query"',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _sync,
                  child: ListView.separated(
                    itemCount: filteredSongs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = filteredSongs[i];
                      return ListTile(
                        title: Text(s.title.isEmpty ? '(Untitled)' : s.title),
                        subtitle: Text(
                          '${s.artist} • Key: ${s.keyName}${s.dirty ? " • Pending sync" : ""}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SongViewerScreen(songId: s.id),
                            ),
                          );
                          ref.invalidate(songsProvider);
                        },
                        onLongPress: () async {
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

                          if (action == 'edit') {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SongEditorScreen(existingId: s.id),
                              ),
                            );
                            ref.invalidate(songsProvider);
                          } else if (action == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete song?'),
                                content: Text('Delete "${s.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
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
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/chrodpro.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/song_content.dart';
import '../core/song_text.dart';
import '../widgets/playlist_dialogs.dart';
import 'song_picker_screen.dart';
import 'song_viewer_screen.dart';

/// One playlist: its songs in order, drag to reorder, swipe-free removal via
/// the trailing button, and "copy everything" for the media team.
class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  Future<void> _addSongs(
    BuildContext context,
    WidgetRef ref,
    Playlist p,
  ) async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(alreadyIn: p.songIds.toSet()),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    final ids = [...p.songIds];
    for (final id in picked) {
      if (!ids.contains(id)) ids.add(id);
    }
    await savePlaylist(ref, p.copyWith(songIds: ids));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Playlist p) async {
    final name = await promptPlaylistName(
      context,
      initial: p.name,
      title: 'Rename playlist',
    );
    if (name == null || name == p.name) return;
    await savePlaylist(ref, p.copyWith(name: name));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Delete "${p.name}"? The songs themselves stay in the library.',
        ),
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
    if (ok != true) return;

    await ref.read(syncServiceProvider).queueDeletePlaylist(p.id);
    ref.invalidate(playlistsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Copies every song in order as one text block. The media team usually
  /// wants lyrics only; the musicians want chords — so ask which.
  Future<void> _copyAll(
    BuildContext context,
    WidgetRef ref,
    Playlist p,
    List<Song> songs,
  ) async {
    final view = await showModalBottomSheet<SongView>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Copy all songs as text',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('Lyrics only'),
              subtitle: const Text('For slides and media'),
              onTap: () => Navigator.pop(ctx, SongView.lyrics),
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Chords only'),
              onTap: () => Navigator.pop(ctx, SongView.chords),
            ),
            ListTile(
              leading: const Icon(Icons.view_agenda_outlined),
              title: const Text('Chords and lyrics'),
              onTap: () => Navigator.pop(ctx, SongView.both),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (view == null) return;

    final text = SongText.renderPlaylist(p, songs, view: view);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${songs.length} songs as text')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistProvider(playlistId));
    final songsAsync = ref.watch(songsProvider);

    final playlist = playlistAsync.valueOrNull;
    final songsById = {
      for (final s in songsAsync.valueOrNull ?? const <Song>[]) s.id: s,
    };

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: playlistAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('This playlist no longer exists.'),
        ),
      );
    }

    // Ids whose song was deleted are kept in the list so they can be removed
    // by hand; copy/queue skip them.
    final present = [
      for (final id in playlist.songIds)
        if (songsById[id] != null) songsById[id]!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            tooltip: 'Copy all as text',
            icon: const Icon(Icons.copy),
            onPressed: present.isEmpty
                ? null
                : () => _copyAll(context, ref, playlist, present),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'rename') _rename(context, ref, playlist);
              if (v == 'delete') _delete(context, ref, playlist);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSongs(context, ref, playlist),
        icon: const Icon(Icons.playlist_add),
        label: const Text('Add songs'),
      ),
      body: playlist.songIds.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No songs yet.\n\nAdd songs here, or long-press a song in '
                  'the library and choose "Add to playlist".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 88), // clears the FAB
              buildDefaultDragHandles: false,
              itemCount: playlist.songIds.length,
              onReorder: (from, to) {
                final ids = [...playlist.songIds];
                if (to > from) to--;
                final moved = ids.removeAt(from);
                ids.insert(to, moved);
                savePlaylist(ref, playlist.copyWith(songIds: ids));
              },
              itemBuilder: (context, i) {
                final id = playlist.songIds[i];
                final song = songsById[id];

                return _PlaylistSongTile(
                  key: ValueKey(id),
                  index: i,
                  song: song,
                  onTap: song == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SongViewerScreen(
                                songId: song.id,
                                queue: [for (final s in present) s.id],
                              ),
                            ),
                          );
                          ref.invalidate(songsProvider);
                        },
                  onRemove: () {
                    final ids = [...playlist.songIds]..removeAt(i);
                    savePlaylist(ref, playlist.copyWith(songIds: ids));
                  },
                );
              },
            ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final int index;
  final Song? song;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    super.key,
    required this.index,
    required this.song,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = song;
    final scheme = Theme.of(context).colorScheme;

    String subtitle;
    if (s == null) {
      subtitle = 'Song no longer in the library';
    } else {
      final parts = <String>[];
      if (s.artist.trim().isNotEmpty) parts.add(s.artist.trim());
      if (SongContent.of(s).hasChords && ChordPro.isMusicalKey(s.keyName)) {
        parts.add('Key: ${s.keyName}');
      }
      subtitle = parts.join(' • ');
    }

    return ListTile(
      onTap: onTap,
      leading: ReorderableDragStartListener(
        index: index,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_handle, color: scheme.outline),
            const SizedBox(width: 8),
            Text('${index + 1}', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
      title: Text(
        s == null ? '(Missing song)' : (s.title.isEmpty ? '(Untitled)' : s.title),
        style: s == null ? TextStyle(color: scheme.error) : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: IconButton(
        tooltip: 'Remove from playlist',
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: onRemove,
      ),
    );
  }
}

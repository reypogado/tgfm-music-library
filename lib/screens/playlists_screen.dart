import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../core/settings.dart';
import '../widgets/playlist_dialogs.dart';
import 'playlist_detail_screen.dart';

/// Saved set lists for services and events, so nobody has to search for and
/// re-open each song while the event is running.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptPlaylistName(context);
    if (name == null) return;
    final p = await createPlaylist(ref, name);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: p.id),
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref, Playlist p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
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
    if (action == null || !context.mounted) return;

    if (action == 'rename') {
      final name = await promptPlaylistName(
        context,
        initial: p.name,
        title: 'Rename playlist',
      );
      if (name == null || name == p.name) return;
      await savePlaylist(ref, p.copyWith(name: name));
      return;
    }

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
    if (ok == true) {
      await ref.read(syncServiceProvider).queueDeletePlaylist(p.id);
      ref.invalidate(playlistsProvider);
    }
  }

  static String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) return 'today';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final year = d.year == now.year ? '' : ' ${d.year}';
    return '${months[d.month - 1]} ${d.day}$year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            tooltip: themeModeLabels[themeMode],
            icon: Icon(themeModeIcons[themeMode]),
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New playlist'),
      ),
      body: playlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No playlists yet.\n\nGroup the songs for a service or '
                  'event so they are ready to open in order.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(syncServiceProvider).syncNow();
              ref.invalidate(playlistsProvider);
              ref.invalidate(songsProvider);
            },
            child: ListView(
              children: [
                for (final p in playlists)
                  ListTile(
                    key: ValueKey(p.id),
                    leading: const Icon(Icons.queue_music),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.songIds.length} '
                      '${p.songIds.length == 1 ? 'song' : 'songs'} • '
                      'Updated ${_when(p.updatedAt)}'
                      '${p.dirty ? ' • Pending sync' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                      ),
                    ),
                    onLongPress: () => _actions(context, ref, p),
                  ),
                const SizedBox(height: 88), // clears the FAB
              ],
            ),
          );
        },
      ),
    );
  }
}

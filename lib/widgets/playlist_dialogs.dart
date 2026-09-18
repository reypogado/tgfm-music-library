import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../core/providers.dart';

/// Asks for a playlist name. Returns null when cancelled or left blank.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String initial = '',
  String title = 'New playlist',
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'e.g. Marahan Voices Playlist',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();

  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Creates an empty playlist locally and queues it for sync.
Future<Playlist> createPlaylist(WidgetRef ref, String name) async {
  final p = Playlist(
    id: const Uuid().v4(),
    name: name,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    dirty: true,
    deleted: false,
  );
  await ref.read(syncServiceProvider).queueUpsertPlaylist(p);
  ref.invalidate(playlistsProvider);
  return p;
}

/// Saves an edited playlist (rename, reorder, add/remove) and refreshes
/// every screen watching it.
Future<void> savePlaylist(WidgetRef ref, Playlist p) async {
  await ref.read(syncServiceProvider).queueUpsertPlaylist(
        p.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch),
      );
  ref.invalidate(playlistsProvider);
}

/// Bottom sheet listing every playlist plus "New playlist…", then appends the
/// song to the chosen one. Songs already in the playlist are not added twice.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final playlists = await ref.read(playlistRepoProvider).listPlaylists();
  if (!context.mounted) return;

  const newKey = '__new__';
  final picked = await showModalBottomSheet<String>(
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
                  'Add to playlist',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('New playlist…'),
                  onTap: () => Navigator.pop(ctx, newKey),
                ),
                for (final p in playlists)
                  ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.songIds.length} '
                      '${p.songIds.length == 1 ? 'song' : 'songs'}',
                    ),
                    trailing: p.songIds.contains(song.id)
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, p.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (picked == null || !context.mounted) return;

  Playlist? target;
  if (picked == newKey) {
    final name = await promptPlaylistName(context);
    if (name == null) return;
    target = await createPlaylist(ref, name);
  } else {
    target = playlists.firstWhere((p) => p.id == picked);
  }

  if (!target.songIds.contains(song.id)) {
    await savePlaylist(
      ref,
      target.copyWith(songIds: [...target.songIds, song.id]),
    );
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added to "${target.name}"')),
  );
}

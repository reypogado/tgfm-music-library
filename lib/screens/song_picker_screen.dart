import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/chrodpro.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/song_content.dart';
import '../core/song_taxonomy.dart';

/// Multi-select over the library. Pops with the chosen song ids in the order
/// they were ticked, so the playlist gets them in the order they were picked.
class SongPickerScreen extends ConsumerStatefulWidget {
  /// Songs already in the playlist; shown ticked and locked.
  final Set<String> alreadyIn;

  const SongPickerScreen({super.key, this.alreadyIn = const {}});

  @override
  ConsumerState<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends ConsumerState<SongPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  final List<String> _picked = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Song s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (s.title.toLowerCase().contains(q)) return true;
    if (s.artist.toLowerCase().contains(q)) return true;
    return SongContent.of(s)
        .lyricSections
        .any((sec) => sec.body.toLowerCase().contains(q));
  }

  String _subtitle(Song s) {
    final parts = <String>[];
    if (s.artist.trim().isNotEmpty) parts.add(s.artist.trim());
    if (ChordPro.isMusicalKey(s.keyName) && SongContent.of(s).hasChords) {
      parts.add('Key: ${s.keyName}');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add songs'),
        actions: [
          TextButton(
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.pop(context, List<String>.from(_picked)),
            child: Text(
              _picked.isEmpty ? 'Add' : 'Add (${_picked.length})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
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
          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (songs) {
                final visible = sortSongs(
                  songs.where(_matches).toList(),
                  SongSort.titleAsc,
                );

                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'No songs in the library yet.'
                            : 'No songs found for "$_query"',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final s = visible[i];
                    final locked = widget.alreadyIn.contains(s.id);
                    final checked = locked || _picked.contains(s.id);
                    final subtitle = _subtitle(s);

                    return CheckboxListTile(
                      key: ValueKey(s.id),
                      value: checked,
                      enabled: !locked,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(s.title.isEmpty ? '(Untitled)' : s.title),
                      subtitle: Text(
                        locked ? 'Already in playlist' : subtitle,
                      ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(s.id);
                        } else {
                          _picked.remove(s.id);
                        }
                      }),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

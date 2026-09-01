# TGFM Music Library

Flutter app (Android/iOS/web/desktop) for a worship team's song library. Songs
carry **chords** and **lyrics** as two separate documents; the viewer shows
either one or both. Offline-first, with a Firestore REST backend.

## Commands

The SDK is managed by [FVM](https://fvm.app) and pinned to Flutter 3.35.5 in
`.fvmrc`. `.fvm/flutter_sdk` is a machine-local symlink into the FVM cache
(gitignored) — recreate it on a new machine with `fvm use`.

```sh
flutter pub get
flutter analyze                 # `--no-pub` to skip re-resolving
flutter test
flutter run -d chrome           # or -d macos
flutter build web               # output in build/web, deployed via vercel.json
```

If `flutter` is not found, `~/.zshrc` must put `$HOME/fvm/default/bin` on
`PATH` (note: no leading dot — FVM 3 moved its cache from `~/.fvm` to `~/fvm`).
Editors read the SDK path from `.vscode/settings.json`
(`dart.flutterSdkPath: .fvm/flutter_sdk`); in Android Studio set the same path
under Settings → Languages & Frameworks → Flutter.

`flutter analyze` currently reports ~15 pre-existing infos/warnings (see
"Known rough edges"). Keep new code from adding to them.

`test/widget_test.dart` is still the stale counter template from `flutter
create` and does not compile — it is the reason `flutter test` is red. Run a
specific file (`flutter test test/song_content_test.dart`) until it is replaced.

## Architecture

Riverpod for wiring, no code generation. All providers live in
[lib/core/providers.dart](lib/core/providers.dart).

```
UI (screens/, widgets/)
  -> SongRepo          domain reads/writes over the local store
    -> LocalDb         sqflite on mobile/desktop, sembast on web
  -> SyncService       outbox push + delta pull
    -> FirestoreRestClient   raw REST, no firebase SDK
```

- **Local-first.** Every write goes to `LocalDb` and an `outbox` row; nothing
  waits on the network. `SyncService.syncNow()` drains the outbox, then pulls
  documents with `updatedAt > last_sync`. A locally `dirty` song wins over the
  server copy.
- **No Firebase SDK.** [lib/core/firestore_rest.dart](lib/core/firestore_rest.dart)
  hand-rolls the Firestore REST value encoding (`stringValue`, `integerValue`,
  …). Project id is `kProjectId` in providers.dart. Requests are unauthenticated
  — [lib/core/auth_rest.dart](lib/core/auth_rest.dart) exists but is not wired
  in, so **security rules must currently be open**.
- **Schema versions.** sqflite is at v4: v2 added `lyrics`, v3 added
  `song_type`/`language`/`theme`, v4 added `themes` and copied `theme` into it.
  Every migration is an additive `ALTER TABLE ... DEFAULT ''`, so no existing
  row is rewritten. The v3 `theme` column is now vestigial.
- **Two `LocalDb` implementations** behind a conditional import in
  [lib/core/local_db_factory.dart](lib/core/local_db_factory.dart). sqflite is
  schema'd and versioned; sembast is schemaless. A new field means adding a
  column *and* an `onUpgrade` step in
  [lib/core/local_db_mobile.dart](lib/core/local_db_mobile.dart); the web store
  needs nothing but tolerant reads in `Song.fromDb`.

## Song content: chords and lyrics are separate

A `Song` holds two independent documents, both in the same `## Section` format:

- `chordPro` — **chords only**, e.g. `## Verse\n[G#m][-][A][-][B]`
- `lyrics` — **lyrics only**, plain text under the same section headings

[lib/core/song_content.dart](lib/core/song_content.dart) is the single place
that reads them. `SongContent.of(song)` returns the chord sections, the lyric
sections, and a `merged` list pairing them section by section (the nth `Verse`
of one document with the nth `Verse` of the other). `SongContent.serialize()`
writes the pair back.

**Legacy data.** Songs created before the split kept everything in `chordPro`,
including lyrics-only songs (which also set `keyName` to the literal string
`"Lyrics"` as a marker). `SongContent` separates those on read, per section: a
section containing `[...]` tokens is chords, anything else is lyrics. This is a
read-time view — stored data is never rewritten until the user saves that song.
Because of this, treat `song.chordPro` as raw storage and go through
`SongContent` everywhere else.

- `ChordPro.isMusicalKey(keyName)` guards the key/transpose UI, so
  `keyName: "Lyrics"` never renders as a key.
- A section with chords typed *inline* with lyrics (`[C]Amazing gra[Am]ce`)
  stays whole in the chord document; `ChordProBlock` positions chords over the
  lyric line.

## Categories and browsing

Songs carry three optional category fields — `songType` (Praise/Worship/Warfare),
`language` (Tagalog/Bisaya/English) and `themes`. Empty means uncategorised;
nothing is ever inferred from the song text.

`themes` is a **list** — a song can carry several. `SongTheme.values` is the
team's own 14-theme chart in their order (Father → Jesus → Spirit → response),
each with a fixed colour used as-is in both light and dark mode with a dark
label. `SongTheme.rank()` drives folder ordering so theme folders never sort
alphabetically. Themes are stored as a single `|`-delimited string
(`encodeThemes`/`decodeThemes` in models.dart) so both the sqflite column and
the hand-rolled Firestore encoder stay plain strings; `decodeThemes` also reads
the older single-valued `theme` field.

Grouping by theme puts a song in **every** one of its theme folders, so folder
counts can sum to more than the library size.

[lib/core/song_taxonomy.dart](lib/core/song_taxonomy.dart) owns the pick-lists
plus `groupSongs()` / `sortSongs()`. The library list groups by song type,
language, theme, artist or key, and sorts by title or date — all chosen from
bottom sheets, so browsing never requires typing. Catch-all folders
(`Uncategorized`, `Unknown artist`, `No key`) always sort last.

Two layout traps worth remembering: bottom-sheet pickers must pass
`isScrollControlled: true` (the default 9/16 height cap hides the last option),
and `DropdownButtonFormField` needs `isExpanded: true` inside a constrained row
or it sizes to its widest menu item and overflows on a narrow phone.

## Theme

`ThemeModeController` in [lib/core/settings.dart](lib/core/settings.dart) holds
the light/dark/system choice, persisted to SharedPreferences and cycled by the
app-bar button. It starts on `ThemeMode.system` and settles onto the saved value
once the store answers — the 3s splash covers the swap.

## Rendering

- [lib/widgets/chordpro_block.dart](lib/widgets/chordpro_block.dart) measures
  text with a `TextPainter` and absolutely positions each chord over its lyric
  offset. Requires the monospace `RobotoMono` family. Its `chordsOnly` mode
  ("Simplify") strips lyrics, dedupes, and collapses repeated blocks into
  `(x3)`.
- [lib/widgets/lyrics_block.dart](lib/widgets/lyrics_block.dart) renders plain
  lyrics in a proportional face — no chord grid.
- Transposition ([lib/core/chrodpro.dart](lib/core/chrodpro.dart), note the
  filename typo) and Nashville numbers
  ([lib/core/nashville.dart](lib/core/nashville.dart)) both rewrite the
  bracketed tokens, so they only apply to the chord document.
- `ChordProView` in [lib/widgets/chordpro_view.dart](lib/widgets/chordpro_view.dart)
  is an unused thin wrapper.

## Conventions

- Section titles come from the `_presets` list in the editor. Trailing digits
  are stripped on serialize (`_normalizeSectionTitle`), so "Verse 2" is stored
  as "Verse" and repeats are distinguished by order.
- `id` is a client-side uuid v4 and doubles as the Firestore document id.
- Timestamps are ms-epoch ints.
- Soft deletes only: `deleted: true` plus a `delete` outbox op.
- Two spaces of indent, single quotes, trailing commas — `flutter_lints`
  defaults via [analysis_options.yaml](analysis_options.yaml).

## Known rough edges

- `SyncService._online` compares a `List<ConnectivityResult>` against
  `ConnectivityResult.none` (connectivity_plus 6 changed the return type), so
  it is always `true`. Harmless — a failed push is caught and retried — but the
  offline short-circuit does not work.
- `FirestoreRestClient.upsertSong` PATCHes without an `updateMask`, so it
  replaces the whole document. `toServerFields()` must always send every field
  or data is dropped server-side.
- `parseSections` computes a `total` count it never uses, left over from a
  disabled "Verse 1 / Verse 2" numbering scheme.

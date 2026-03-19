class SongSection {
  final String title; // e.g. "Verse 1", "Chorus"
  final String body;  // chordpro body only
  const SongSection({required this.title, required this.body});

  SongSection copyWith({String? title, String? body}) =>
      SongSection(title: title ?? this.title, body: body ?? this.body);
}

/// Parse text that uses "## Section" headers.
List<SongSection> parseSections(String text) {
  final src = text.replaceAll('\r\n', '\n').trim();
  if (src.isEmpty) return const [SongSection(title: 'Verse 1', body: '')];

  final lines = src.split('\n');
  final sections = <SongSection>[];

  String currentTitle = 'Verse 1';
  final buf = StringBuffer();

  bool sawHeader = false;

  void flush() {
    final body = buf.toString().trimRight();
    if (body.isNotEmpty || sections.isNotEmpty) {
      sections.add(SongSection(title: currentTitle, body: body));
    }
    buf.clear();
  }

  for (final line in lines) {
    if (line.startsWith('## ')) {
      sawHeader = true;
      flush();
      currentTitle = line.substring(3).trim().isEmpty ? 'Section' : line.substring(3).trim();
      continue;
    }
    buf.writeln(line);
  }
  flush();

  // If no headers were found, treat whole text as Verse 1
  if (!sawHeader) {
    return [SongSection(title: 'Verse 1', body: src)];
  }

  // Remove empty leading section if any
  return sections.where((s) => s.title.trim().isNotEmpty).toList();
}

String serializeSections(List<SongSection> sections) {
  final cleaned = sections
      .where((s) => s.title.trim().isNotEmpty)
      .map((s) => SongSection(title: s.title.trim(), body: s.body.trimRight()))
      .toList();

  if (cleaned.isEmpty) return '';

  final out = StringBuffer();
  for (int i = 0; i < cleaned.length; i++) {
    final s = cleaned[i];
    out.writeln('## ${s.title}');
    if (s.body.isNotEmpty) out.writeln(s.body);
    if (i != cleaned.length - 1) out.writeln(); // blank line between sections
  }
  return out.toString().trimRight();
}
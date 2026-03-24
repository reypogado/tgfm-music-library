class SongSection {
  final String title;
  final String body;

  const SongSection({
    required this.title,
    required this.body,
  });
}

String _normalizeSectionTitle(String title) {
  return title.replaceAll(RegExp(r'\s+\d+$'), '').trim();
}

List<SongSection> parseSections(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');

  final rawSections = <SongSection>[];

  String? currentTitle;
  final currentBody = <String>[];

  bool isHeaderLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('## ');
  }

  void flushRaw() {
    if (currentTitle == null) return;

    rawSections.add(
      SongSection(
        title: _normalizeSectionTitle(currentTitle!),
        body: currentBody.join('\n').trimRight(),
      ),
    );

    currentBody.clear();
  }

  for (final line in lines) {
    if (isHeaderLine(line)) {
      flushRaw();
      currentTitle = line.trim().substring(3).trim();
    } else {
      currentBody.add(line);
    }
  }

  flushRaw();

  if (rawSections.isEmpty) return [];

  final totals = <String, int>{};
  for (final sec in rawSections) {
    totals[sec.title] = (totals[sec.title] ?? 0) + 1;
  }

  final seen = <String, int>{};
  final result = <SongSection>[];

  for (final sec in rawSections) {
    final count = (seen[sec.title] ?? 0) + 1;
    seen[sec.title] = count;

    final total = totals[sec.title] ?? 1;

    final displayTitle = total > 1
        ? '${sec.title} $count'
        : '${sec.title} 1';

    result.add(
      SongSection(
        title: displayTitle,
        body: sec.body,
      ),
    );
  }

  return result;
}

String serializeSections(List<SongSection> sections) {
  return sections.map((s) {
    final normalizedTitle = _normalizeSectionTitle(s.title);
    return '## $normalizedTitle\n${s.body}'.trimRight();
  }).join('\n\n');
}
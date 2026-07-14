/// Fakes an "AI" summary as a plain excerpt of the note's own content.
/// Stands in until the real FLAN-T5 summarization backend (AGENT.md
/// §3.2/§6) is built — the UI that displays this labels it as a
/// placeholder rather than pretending it's real.
String generateHardcodedSummary(String content) {
  final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return 'Nothing to summarize yet — add some content to this note first.';
  }

  final words = normalized.split(' ');
  final excerpt = words.take(30).join(' ');
  final ellipsis = words.length > 30 ? '…' : '';

  return '$excerpt$ellipsis';
}

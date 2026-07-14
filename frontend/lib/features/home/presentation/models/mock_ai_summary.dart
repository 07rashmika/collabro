class MockAiSummary {
  final String title;
  final String generatedLabel;
  final String snippet;

  const MockAiSummary({
    required this.title,
    required this.generatedLabel,
    required this.snippet,
  });
}

/// Hardcoded on purpose — the AI summarization backend module (FLAN-T5,
/// per AGENT.md §3.2/§6) hasn't been built yet.
const List<MockAiSummary> mockAiSummaries = [
  MockAiSummary(
    title: 'Ch. 4: Machine Learning Basics',
    generatedLabel: 'Generated 2hr ago',
    snippet:
        'Key concepts include supervised vs unsupervised learning, gradient descent, and...',
  ),
  MockAiSummary(
    title: 'Physics Lab Notes: Optics',
    generatedLabel: 'Generated yesterday',
    snippet:
        'Summary of focal length calculations, interference patterns observed, and error...',
  ),
];

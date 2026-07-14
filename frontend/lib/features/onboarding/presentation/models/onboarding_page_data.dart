class OnboardingPageData {
  final String headline1;
  final String headline2;
  final String headline3;
  final String body;
  final String badge;

  const OnboardingPageData({
    required this.headline1,
    required this.headline2,
    required this.headline3,
    required this.body,
    required this.badge,
  });
}

const List<OnboardingPageData> onboardingPages = [
  OnboardingPageData(
    headline1: 'Collaborate.',
    headline2: 'Learn.',
    headline3: 'Excel.',
    body:
        'Join the exclusive academic network. Connect with peers, organize study sessions, and access shared resources.',
    badge: 'University email verification required.',
  ),
  OnboardingPageData(
    headline1: 'Find Your',
    headline2: 'Perfect',
    headline3: 'Study Partner.',
    body:
        'Our AI-powered matching system pairs you with students who share your courses, interests, and study style.',
    badge: 'AI-powered matching',
  ),
  OnboardingPageData(
    headline1: 'Share Notes.',
    headline2: 'Generate',
    headline3: 'Summaries.',
    body:
        'Upload your notes and let our AI generate comprehensive summaries, flashcards, and study guides instantly.',
    badge: 'Powered by AI',
  ),
];
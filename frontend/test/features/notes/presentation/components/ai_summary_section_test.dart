import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/notes/presentation/components/ai_summary_section.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  group('AiSummarySection — no summary yet', () {
    testWidgets('shows the generate prompt and button', (tester) async {
      await tester.pumpWidget(
        wrap(
          AiSummarySection(
            summary: null,
            isGenerating: false,
            onGenerate: () {},
          ),
        ),
      );

      expect(
        find.text('Generate a quick summary of this note.'),
        findsOneWidget,
      );
      expect(find.text('Generate Summary'), findsOneWidget);
      expect(find.text('Regenerate'), findsNothing);
    });

    testWidgets('tapping "Generate Summary" invokes onGenerate', (
      tester,
    ) async {
      var generateCount = 0;
      await tester.pumpWidget(
        wrap(
          AiSummarySection(
            summary: null,
            isGenerating: false,
            onGenerate: () => generateCount++,
          ),
        ),
      );

      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(generateCount, 1);
    });

    testWidgets('shows a spinner and disables the button while busy', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AiSummarySection(
            summary: null,
            isGenerating: true,
            onGenerate: () {},
          ),
        ),
      );

      // PrimaryButton(isLoading: true) swaps its label for a spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generate Summary'), findsNothing);

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('AiSummarySection — summary present', () {
    testWidgets('shows the summary text, Regenerate, and a share action', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AiSummarySection(
            title: 'Lecture recap',
            summary: 'A short recap of the session.',
            isGenerating: false,
            onGenerate: () {},
          ),
        ),
      );

      expect(find.text('A short recap of the session.'), findsOneWidget);
      expect(find.text('Regenerate'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.text('Generate Summary'), findsNothing);
    });

    testWidgets('tapping "Regenerate" invokes onGenerate again', (
      tester,
    ) async {
      var generateCount = 0;
      await tester.pumpWidget(
        wrap(
          AiSummarySection(
            summary: 'A short recap.',
            isGenerating: false,
            onGenerate: () => generateCount++,
          ),
        ),
      );

      await tester.tap(find.text('Regenerate'));
      await tester.pump();

      expect(generateCount, 1);
    });
  });
}

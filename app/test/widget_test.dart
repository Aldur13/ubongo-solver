import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ubongo_solver/main.dart';

void main() {
  testWidgets('home screen navigates to Manual Entry', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UbongoSolverApp()));
    await tester.pumpAndSettle();

    expect(find.text('Ubongo Solver'), findsOneWidget);

    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Tap cells to mark the puzzle outline'), findsOneWidget);
  });

  testWidgets(
    'marking a 2x2 board and requiring the square piece solves the puzzle',
    (tester) async {
      // The manual entry screen's grid can be tall at the default 6x6 size;
      // give the test viewport plenty of room so nothing needed for
      // interaction sits below the fold (mirrors the pattern used for
      // Cluedo-bot-mobile's tall-screen widget tests).
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: UbongoSolverApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manual Entry'));
      await tester.pumpAndSettle();

      // Grid defaults to 6x6; shrink both dimensions to 2x2.
      final removeButtons = find.byIcon(Icons.remove);
      expect(removeButtons, findsNWidgets(2));
      for (var i = 0; i < 4; i++) {
        await tester.tap(removeButtons.at(0));
        await tester.pump();
      }
      for (var i = 0; i < 4; i++) {
        await tester.tap(removeButtons.at(1));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(cells, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        await tester.tap(cells.at(i));
        await tester.pump();
      }

      // P4 is the placeholder square tetromino (4 cells) — exactly fills
      // a 2x2 board. Find its count row, then tap its "+" stepper button.
      final p4Row = find
          .ancestor(of: find.textContaining('P4 —'), matching: find.byType(Row))
          .first;
      final p4AddButton = find.descendant(
        of: p4Row,
        matching: find.byIcon(Icons.add_circle_outline),
      );
      await tester.ensureVisible(p4AddButton);
      await tester.tap(p4AddButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solve'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No solution'), findsNothing);
      expect(find.textContaining('P4'), findsWidgets);
    },
  );
}

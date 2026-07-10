import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_solver/data/scanned_board_data.dart';
import 'package:ubongo_solver/screens/grid_markup_screen.dart';
import 'package:ubongo_solver/state/puzzle_session.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  testWidgets('tapping a cell on the markup grid toggles it in session state', (tester) async {
    // Stands in for a photographed-and-corrected card — the markup
    // screen's own logic doesn't care where the image came from, only
    // that it can render it as a background.
    final data = ScannedBoardData(corrected: CorrectedCardImage(RgbImage.blank(40, 40)));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(puzzleSessionProvider.notifier).setGridSize(2, 2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GridMarkupScreen(data: data)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(puzzleSessionProvider).boardCells, isEmpty);
    expect(find.textContaining('Auto-detected'), findsNothing);

    final cells = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );
    expect(cells, findsNWidgets(4));

    await tester.tap(cells.first);
    await tester.pump();
    expect(container.read(puzzleSessionProvider).boardCells.length, 1);

    await tester.tap(cells.first);
    await tester.pump();
    expect(container.read(puzzleSessionProvider).boardCells, isEmpty);
  });

  testWidgets('shows the auto-detected banner when reached from a successful detection', (tester) async {
    final data = ScannedBoardData(
      corrected: CorrectedCardImage(RgbImage.blank(40, 40)),
      detectedShape: DetectedBoardShape(
        width: 2,
        height: 2,
        cells: {const CellCoord(0, 0), const CellCoord(0, 1)},
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(puzzleSessionProvider.notifier).setGridSize(2, 2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GridMarkupScreen(data: data)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Auto-detected'), findsOneWidget);
  });
}

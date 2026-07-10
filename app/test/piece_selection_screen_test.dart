import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubongo_solver/screens/piece_selection_screen.dart';
import 'package:ubongo_solver/state/puzzle_session.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  testWidgets('tapping a piece\'s + button adds it to the required-pieces list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final corrected = CorrectedCardImage(RgbImage.blank(40, 40));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PieceSelectionScreen(corrected: corrected)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(puzzleSessionProvider).slots, isEmpty);
    expect(find.text('Select Pieces'), findsOneWidget);

    final p4Row = find
        .ancestor(of: find.textContaining('P4 —'), matching: find.byType(Row))
        .first;
    final p4AddButton = find.descendant(
      of: p4Row,
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.ensureVisible(p4AddButton);
    await tester.tap(p4AddButton);
    await tester.pump();

    expect(container.read(puzzleSessionProvider).slots.length, 1);

    final p4RemoveButton = find.descendant(
      of: p4Row,
      matching: find.byIcon(Icons.remove_circle_outline),
    );
    await tester.tap(p4RemoveButton);
    await tester.pump();

    expect(container.read(puzzleSessionProvider).slots, isEmpty);
  });
}

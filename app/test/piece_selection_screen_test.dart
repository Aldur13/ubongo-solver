import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubongo_solver/screens/piece_selection_screen.dart';
import 'package:ubongo_solver/state/puzzle_session.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  testWidgets('tapping a piece chip adds it to the required-pieces list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final corrected = CorrectedCardImage(RgbImage.blank(40, 40));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PieceSelectionScreen(corrected: corrected)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(puzzleSessionProvider).slots, isEmpty);
    expect(find.text('Select Pieces'), findsOneWidget);

    await tester.tap(find.text('P4 (4)'));
    await tester.pump();

    expect(container.read(puzzleSessionProvider).slots.length, 1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(container.read(puzzleSessionProvider).slots, isEmpty);
  });
}

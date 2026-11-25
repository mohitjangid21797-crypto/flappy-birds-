import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flappy_birds_game/main.dart';

void main() {
  testWidgets('Flappy Bird game renders ready screen and starts on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FlappyBirdApp());
    await tester.pump();

    expect(find.text('FLAPPY BIRD'), findsWidgets);
    expect(find.text('TAP OR PRESS SPACE TO FLY'), findsOneWidget);
    expect(find.text('CLASSIC'), findsOneWidget);

    // Switch difficulty to Chill
    await tester.tap(find.text('CHILL'));
    await tester.pump();

    // Tap the playfield to start playing
    await tester.tapAt(const Offset(120, 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FLAPPY BIRD'), findsNothing);
    expect(find.text('0'), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Pause and verify pause modal
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('PAUSED'), findsWidgets);
    expect(find.text('RESUME'), findsOneWidget);
  });
}

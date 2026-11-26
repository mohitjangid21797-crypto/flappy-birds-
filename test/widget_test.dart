import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flappy_birds_game/main.dart';

void main() {
  testWidgets(
      '2130 Group 3D Flappy Bird works offline without Daily Board and starts game',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FlappyBirdApp());
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('FLAPPY BIRD'), findsWidgets);
    expect(find.text('Heart Run'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Speed Up'), findsOneWidget);
    expect(find.text('Daily Board'), findsNothing);
    expect(find.text('Daily Challenge'), findsNothing);

    await tester.tapAt(const Offset(120, 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FLAPPY BIRD'), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}

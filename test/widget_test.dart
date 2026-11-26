import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flappy_birds_game/main.dart';

void main() {
  testWidgets(
      '2130 Group 3D Flappy Bird renders Daily Challenge and Daily Board modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FlappyBirdApp());
    await tester.pump();

    expect(find.text("LET'S PLAY WITH 2130 GROUP"), findsOneWidget);
    expect(find.text('FLAPPY BIRD'), findsWidgets);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Daily Board'), findsOneWidget);

    // Select Daily Challenge mode
    await tester.tap(find.text('Daily Challenge'));
    await tester.pump();
    expect(find.text('Leaderboard'), findsOneWidget);

    // Open Daily Leaderboard modal
    await tester.tap(find.text('Leaderboard'));
    await tester.pump();
    expect(find.text('Play Daily Challenge'), findsNothing);
    expect(find.text('Keep Playing'), findsOneWidget);

    // Close modal and start playing
    await tester.tap(find.text('Keep Playing'));
    await tester.pump();

    await tester.tapAt(const Offset(120, 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FLAPPY BIRD'), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}

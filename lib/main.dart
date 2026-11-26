import 'package:material_ui/material_ui.dart';

import 'game/flappy_game_screen.dart';
import 'game/game_config.dart';

void main() {
  runApp(const FlappyBirdApp());
}

class FlappyBirdApp extends StatelessWidget {
  const FlappyBirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tap Flying Bird',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.skyTop,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const FlappyGameScreen(key: ValueKey('flappy_2130_v4')),
    );
  }
}

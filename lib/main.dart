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
      title: 'Flappy Bird',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.pipeMain,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const FlappyGameScreen(),
    );
  }
}

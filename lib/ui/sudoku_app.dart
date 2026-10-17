import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:sudoku_flutter/game/sudoku_puzzle_pool.dart';
import 'package:sudoku_flutter/ui/sudoku_page.dart';

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key, this.puzzlePool});

  final SudokuPuzzlePool? puzzlePool;

  static const _seedColor = Color.fromARGB(255, 102, 49, 101);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          surface: const Color(0xFFF6F6F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F8),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBE8CC9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LoaderOverlay(
        child: SudokuPage(title: 'Sudoku', puzzlePool: puzzlePool),
      ),
    );
  }
}

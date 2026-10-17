import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';

class ScoreboardStore {
  static const _keyPrefix = 'sudoku_best_times_';

  Future<Map<SudokuDifficulty, List<int>>> loadScores() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final difficulty in SudokuDifficulty.values)
        difficulty: _readScores(preferences, difficulty),
    };
  }

  Future<int?> recordTime({
    required SudokuDifficulty difficulty,
    required int seconds,
  }) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', 'Must not be negative.');
    }

    final preferences = await SharedPreferences.getInstance();
    final scores = _readScores(preferences, difficulty)..add(seconds);
    scores.sort();
    final rank = scores.indexOf(seconds) + 1;
    final bestThree = scores.take(3).toList();
    final saved = await preferences.setString(
      _keyFor(difficulty),
      jsonEncode(bestThree),
    );
    if (!saved) {
      throw StateError('Could not save the scoreboard.');
    }

    return rank <= 3 ? rank : null;
  }

  List<int> _readScores(
    SharedPreferences preferences,
    SudokuDifficulty difficulty,
  ) {
    final encoded = preferences.getString(_keyFor(difficulty));
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded);
    if (decoded is! List<dynamic> ||
        decoded.any((score) => score is! int || score < 0)) {
      throw FormatException('Invalid saved scores for ${difficulty.name}.');
    }

    final scores = decoded.cast<int>()..sort();
    return scores.take(3).toList();
  }

  String _keyFor(SudokuDifficulty difficulty) =>
      '$_keyPrefix${difficulty.name}';
}

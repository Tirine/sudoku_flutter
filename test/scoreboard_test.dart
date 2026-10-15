import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_flutter/scoreboard.dart';
import 'package:sudoku_flutter/sudoku.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('keeps the three fastest times and returns their rank', () async {
    final store = ScoreboardStore();

    expect(
      await store.recordTime(
        difficulty: SudokuDifficulty.easy,
        seconds: 90,
      ),
      1,
    );
    expect(
      await store.recordTime(
        difficulty: SudokuDifficulty.easy,
        seconds: 60,
      ),
      1,
    );
    expect(
      await store.recordTime(
        difficulty: SudokuDifficulty.easy,
        seconds: 75,
      ),
      2,
    );
    expect(
      await store.recordTime(
        difficulty: SudokuDifficulty.easy,
        seconds: 100,
      ),
      isNull,
    );

    final scores = await ScoreboardStore().loadScores();
    expect(scores[SudokuDifficulty.easy], [60, 75, 90]);
    expect(scores[SudokuDifficulty.medium], isEmpty);
  });

  test('stores records independently by difficulty', () async {
    final store = ScoreboardStore();
    await store.recordTime(difficulty: SudokuDifficulty.easy, seconds: 42);
    await store.recordTime(difficulty: SudokuDifficulty.hard, seconds: 68);

    final scores = await store.loadScores();
    expect(scores[SudokuDifficulty.easy], [42]);
    expect(scores[SudokuDifficulty.hard], [68]);
  });
}

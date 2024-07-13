// This is a basic Flutter test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_flutter/sudoku.dart';

void main() {
  test('Sudoku Creation', () async {
    final Sudoku sudoku = Sudoku();
    await sudoku.init();
    expect(sudoku.solution.any((row) => row.contains(0)), false);
    expect(sudoku.board.every((row) => row.contains(0)), true);
  });

  test('Sudoku with seed create exactly the same', () async {
    final Sudoku sudoku1 = Sudoku(seed: 3141592653589793238);
    final Sudoku sudoku2 = Sudoku(seed: 3141592653589793238);

    var firstPromise = sudoku1.init();
    await sudoku2.init();
    await firstPromise;

    expect(sudoku1.solution, sudoku2.solution);
    expect(sudoku1.board, sudoku2.board);
  });

  test('Sudoku speed test', () async {
    final t0 = DateTime.now();
    for (var i = 0; i < 2; i++) {
      final Sudoku sudoku =
          Sudoku(seed: 1000 + i, difficulty: SudokuDifficulty.extreme);
      await sudoku.init();
    }
    final t1 = DateTime.now();
    print(t1.millisecondsSinceEpoch - t0.millisecondsSinceEpoch);

    // expect(sudoku1.solution, sudoku2.solution);
    // expect(sudoku1.board, sudoku2.board);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/game/sudoku_logical_generator.dart';

void main() {
  test('logical generation check solves without changing the source board',
      () async {
    final puzzle = await SudokuGenerator.create(seed: 123456);
    final source = SudokuGenerator.cloneBoard(puzzle.board);

    expect(SudokuLogicalGenerator().canSolve(source), isTrue);
    expect(source, puzzle.board);
  });

  test(
      'logical generation check rejects duplicate clues without changing the board',
      () {
    final source = SudokuGenerator.createEmpty()
      ..[0][0] = 1
      ..[0][1] = 1;
    final before = SudokuGenerator.cloneBoard(source);

    expect(SudokuLogicalGenerator().canSolve(source), isFalse);
    expect(source, before);
  });

  test('uniqueness checks leave the supplied board unchanged', () async {
    final puzzle = await SudokuGenerator.create(seed: 123456);
    final source = SudokuGenerator.cloneBoard(puzzle.board);
    final clue = _firstClue(source);

    await puzzle.isUniqueCell(source, clue.$1, clue.$2);

    expect(source, puzzle.board);
  });
}

(int, int) _firstClue(Board board) {
  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 9; column++) {
      if (board[row][column] != 0) return (row, column);
    }
  }
  throw StateError('Expected at least one clue.');
}

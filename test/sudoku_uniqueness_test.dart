import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';

void main() {
  test('reused uniqueness state leaves the supplied board unchanged', () async {
    final puzzle = await SudokuGenerator.create(seed: 123456);
    final source = SudokuGenerator.cloneBoard(puzzle.board);
    final clues = [
      for (var row = 0; row < 9; row++)
        for (var column = 0; column < 9; column++)
          if (source[row][column] != 0) (row, column),
    ].take(3);

    for (final clue in clues) {
      await puzzle.isUniqueCell(source, clue.$1, clue.$2);
    }

    expect(source, puzzle.board);
  });
}

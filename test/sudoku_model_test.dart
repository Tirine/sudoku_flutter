import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/sudoku.dart';

void main() {
  test('empty uninitialized puzzle reports its state and fill status', () {
    final game = Sudoku(initialise: false);

    expect(game.initialised, isFalse);
    expect(game.filled(), isFalse);
    expect(game.board, Sudoku.createEmpty());
  });

  test('filled puzzle reports complete and verifies against its solution', () {
    final game = Sudoku(initialise: false);
    const solved = [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 4, 5, 6, 7, 8, 9, 1],
      [5, 6, 7, 8, 9, 1, 2, 3, 4],
      [8, 9, 1, 2, 3, 4, 5, 6, 7],
      [3, 4, 5, 6, 7, 8, 9, 1, 2],
      [6, 7, 8, 9, 1, 2, 3, 4, 5],
      [9, 1, 2, 3, 4, 5, 6, 7, 8],
    ];
    for (var row = 0; row < 9; row++) {
      game.solution[row].setAll(0, solved[row]);
      game.board[row].setAll(0, solved[row]);
    }

    expect(game.filled(), isTrue);
    expect(game.verify(), isTrue);
    game.board[0][0] = 9;
    expect(game.verify(), isFalse);
  });

  test('isValidCell rejects row, column, and box conflicts', () {
    final board = Sudoku.createEmpty();
    board[0][0] = 5;

    expect(Sudoku.isValidCell(board, 0, 1, 5), isFalse);
    expect(Sudoku.isValidCell(board, 1, 0, 5), isFalse);
    expect(Sudoku.isValidCell(board, 1, 1, 5), isFalse);
    expect(Sudoku.isValidCell(board, 1, 1, 6), isTrue);
  });

  test('cloneBoard copies each row independently', () {
    final original = Sudoku.createEmpty()..[0][0] = 4;
    final clone = Sudoku.cloneBoard(original);

    expect(clone, original);
    clone[0][0] = 9;
    clone[1][1] = 7;
    expect(original[0][0], 4);
    expect(original[1][1], 0);
  });
}

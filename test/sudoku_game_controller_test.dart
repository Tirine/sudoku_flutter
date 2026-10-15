import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/sudoku.dart';
import 'package:sudoku_flutter/sudoku_game_controller.dart';

void main() {
  late Sudoku game;
  late SudokuGameController controller;

  setUp(() {
    game = Sudoku(difficulty: SudokuDifficulty.easy, initialise: false);
    controller = SudokuGameController(
      initialGame: game,
      startTimer: false,
    );
  });

  tearDown(() => controller.dispose());

  test('supports number then cell and cell then number entry', () {
    controller.selectNumber(5);
    controller.selectCell(0, 0);
    expect(controller.valueAt(0, 0), 5);
    expect(controller.selectedNumber, 5);

    controller.selectNumber(5);
    controller.selectCell(0, 1);
    expect(controller.selectedRow, 0);
    expect(controller.selectedCol, 1);
    controller.selectNumber(7);
    expect(controller.valueAt(0, 1), 7);
  });

  test('notes toggle on and off, and clear when entering a value', () {
    controller.toggleNotes(true);
    controller.selectCell(0, 0);
    controller.selectNumber(3);
    expect(controller.notesAt(0, 0), contains(3));
    expect(controller.valueAt(0, 0), 0);

    controller.selectNumber(3);
    expect(controller.notesAt(0, 0), isEmpty);

    controller.toggleNotes(false);
    controller.selectNumber(4);
    expect(controller.valueAt(0, 0), 4);
    expect(controller.notesAt(0, 0), isEmpty);
  });

  test('does not allow editing given cells or completed games', () {
    game.board[0][0] = 9;
    controller.load(game, startTimer: false);
    controller.selectCell(0, 0);
    controller.selectNumber(1);
    expect(controller.valueAt(0, 0), 9);

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
    controller.load(game, startTimer: false);
    expect(controller.verifyAndComplete(), isTrue);
    controller.selectCell(0, 1);
    controller.selectNumber(2);
    expect(controller.valueAt(0, 1), 2);
  });

  test('loading another game resets play state', () {
    controller.selectCell(0, 0);
    controller.toggleNotes(true);
    controller.selectNumber(2);
    expect(controller.notesAt(0, 0), contains(2));

    final nextGame = Sudoku(
      seed: 2,
      difficulty: SudokuDifficulty.medium,
      initialise: false,
    );
    controller.load(nextGame, startTimer: false);

    expect(controller.game, same(nextGame));
    expect(controller.elapsedSeconds, 0);
    expect(controller.notesEnabled, isFalse);
    expect(controller.notesAt(0, 0), isEmpty);
    expect(controller.selectedRow, -1);
    expect(controller.selectedCol, -1);
    expect(controller.selectedNumber, -1);
    expect(controller.isComplete, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/game/sudoku_logic_solver.dart';

const _specialSeedDiagonals = <int, List<int>>{
  314159265: [3, 1, 4, 1, 5, 9, 2, 6, 5],
  628318531: [6, 2, 8, 3, 1, 8, 5, 3, 1],
  123456789: [1, 2, 3, 4, 5, 6, 7, 8, 9],
  987654321: [9, 8, 7, 6, 5, 4, 3, 2, 1],
  241421356: [2, 4, 1, 4, 2, 1, 3, 5, 6],
  915965594: [9, 1, 5, 9, 6, 5, 5, 9, 4],
};

void main() {
  late SudokuGenerator puzzle;
  late SudokuGenerator extremePuzzle;
  late SudokuGenerator almostImpossiblePuzzle;

  setUpAll(() async {
    puzzle = await SudokuGenerator.create(
        seed: 123456, difficulty: SudokuDifficulty.easy);
    extremePuzzle = await SudokuGenerator.create(
      seed: 654321,
      difficulty: SudokuDifficulty.extreme,
    );
    almostImpossiblePuzzle = await SudokuGenerator.create(
      seed: 789012,
      difficulty: SudokuDifficulty.extreme,
    );
  });

  test('generates a valid puzzle with a matching complete solution', () {
    expect(_isCompleteValidBoard(puzzle.solution), isTrue);
    expect(_isValidPartialBoard(puzzle.board), isTrue);

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        final clue = puzzle.board[row][column];
        if (clue != 0) {
          expect(clue, puzzle.solution[row][column]);
        }
      }
    }

    expect(puzzle.initialised, isTrue);
    expect(puzzle.filled(), isFalse);
  });

  test('generated puzzle has exactly one solution', () {
    expect(_countSolutions(puzzle.board), 1);
  });

  test('same seed and difficulty reproduce the puzzle and solution', () async {
    final repeated = await SudokuGenerator.create(
      seed: 123456,
      difficulty: SudokuDifficulty.easy,
    );

    expect(repeated.board, puzzle.board);
    expect(repeated.solution, puzzle.solution);
  });

  test('random puzzle seed replays the displayed puzzle', () async {
    final randomPuzzle = await SudokuGenerator.create();
    final replay = await SudokuGenerator.create(
      seed: randomPuzzle.seed,
      difficulty: randomPuzzle.difficulty,
    );

    expect(replay.board, randomPuzzle.board);
    expect(replay.solution, randomPuzzle.solution);
  });

  test('seeds 76 and 100 keep a custom clue in every row and column', () async {
    for (final seed in [76, 100]) {
      final puzzle = await SudokuGenerator.create(seed: seed);
      expect(
        puzzle.board.every((row) => row.any((value) => value != 0)),
        isTrue,
        reason: 'Seed $seed should retain its custom row clues.',
      );
      expect(
        List.generate(9, (column) => column).every(
          (column) => puzzle.board.any((row) => row[column] != 0),
        ),
        isTrue,
        reason: 'Seed $seed should retain its custom column clues.',
      );
    }
  });

  test('special seeds generate valid puzzles from their diagonal patterns',
      () async {
    for (final entry in _specialSeedDiagonals.entries) {
      final seed = entry.key;
      final diagonal = entry.value;
      final puzzle = await SudokuGenerator.create(seed: seed);

      expect(
        List.generate(9, (index) => puzzle.solution[index][index]),
        diagonal,
        reason:
            'Seed $seed should preserve its custom pattern in the solution.',
      );
      expect(
        _isCompleteValidBoard(puzzle.solution),
        isTrue,
        reason: 'Seed $seed should produce a valid complete solution.',
      );
      expect(
        _isValidPartialBoard(puzzle.board),
        isTrue,
        reason: 'Seed $seed should produce a valid puzzle.',
      );
      expect(
        _countSolutions(puzzle.board),
        1,
        reason: 'Seed $seed should produce a uniquely solvable puzzle.',
      );
    }
  });

  test('extreme puzzle is minimal while retaining a unique solution', () {
    expect(_countSolutions(extremePuzzle.board), 1);

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (extremePuzzle.board[row][column] == 0) continue;

        final withClueRemoved = SudokuGenerator.cloneBoard(extremePuzzle.board);
        withClueRemoved[row][column] = 0;
        expect(
          _countSolutions(withClueRemoved),
          greaterThan(1),
          reason:
              'Removing clue at row ${row + 1}, column ${column + 1} should '
              'allow multiple solutions.',
        );
      }
    }
  });

  test(
      'almost-impossible (removed, logic in extreme) puzzle is unique and solvable without guessing',
      () {
    expect(_countSolutions(almostImpossiblePuzzle.board), 1);
    expect(SudokuLogicSolver().canSolve(almostImpossiblePuzzle.board), isTrue);

    final clueCount = almostImpossiblePuzzle.board
        .expand((row) => row)
        .where((value) => value != 0)
        .length;
    expect(clueCount, greaterThanOrEqualTo(17));
  });

  test(
      'seed 79505584 produces a unique almost-impossible (removed, logic in extreme) puzzle',
      () async {
    final seededPuzzle = await SudokuGenerator.create(
      seed: 79505584,
      difficulty: SudokuDifficulty.extreme,
    );

    expect(_countSolutions(seededPuzzle.board), 1);
    expect(SudokuLogicSolver().canSolve(seededPuzzle.board), isTrue);
  });

  test(
      'almost-impossible (removed, logic in extreme) puzzle cannot lose another clue and stay valid',
      () {
    final solver = SudokuLogicSolver();
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (almostImpossiblePuzzle.board[row][column] == 0) continue;

        final withClueRemoved =
            SudokuGenerator.cloneBoard(almostImpossiblePuzzle.board);
        withClueRemoved[row][column] = 0;
        final stillUnique = _countSolutions(withClueRemoved) == 1;
        final stillSolvableWithoutGuessing = solver.canSolve(withClueRemoved);
        expect(
          stillUnique && stillSolvableWithoutGuessing,
          isFalse,
          reason: 'Removing clue at row ${row + 1}, column ${column + 1} must '
              'break uniqueness or require a technique this tier does not use.',
        );
      }
    }
  });
}

bool _isCompleteValidBoard(Board board) {
  if (!_hasBoardShape(board)) return false;

  for (var index = 0; index < 9; index++) {
    final row = board[index];
    final column = [for (var row = 0; row < 9; row++) board[row][index]];
    if (!_containsDigitsOneToNine(row) || !_containsDigitsOneToNine(column)) {
      return false;
    }
  }

  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxColumn = 0; boxColumn < 3; boxColumn++) {
      final box = [
        for (var row = boxRow * 3; row < boxRow * 3 + 3; row++)
          for (var column = boxColumn * 3; column < boxColumn * 3 + 3; column++)
            board[row][column],
      ];
      if (!_containsDigitsOneToNine(box)) return false;
    }
  }

  return true;
}

bool _isValidPartialBoard(Board board) {
  if (!_hasBoardShape(board)) return false;
  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 9; column++) {
      final value = board[row][column];
      if (value < 0 || value > 9) return false;
      if (value != 0 &&
          !SudokuGenerator.isValidCell(board, row, column, value)) {
        // isValidCell sees the value in its own cell, so check against a copy
        // with that cell temporarily cleared.
        final withoutCell = SudokuGenerator.cloneBoard(board);
        withoutCell[row][column] = 0;
        if (!SudokuGenerator.isValidCell(withoutCell, row, column, value))
          return false;
      }
    }
  }
  return true;
}

bool _hasBoardShape(Board board) =>
    board.length == 9 && board.every((row) => row.length == 9);

bool _containsDigitsOneToNine(List<int> values) =>
    values.length == 9 &&
    values.toSet().length == 9 &&
    values.toSet().containsAll(
          List<int>.generate(9, (index) => index + 1),
        );

int _countSolutions(Board source) {
  final board = SudokuGenerator.cloneBoard(source);

  int search() {
    var bestRow = -1;
    var bestColumn = -1;
    List<int>? bestCandidates;

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (board[row][column] != 0) continue;

        final candidates = [
          for (var value = 1; value <= 9; value++)
            if (SudokuGenerator.isValidCell(board, row, column, value)) value,
        ];
        if (candidates.isEmpty) return 0;
        if (bestCandidates == null ||
            candidates.length < bestCandidates.length) {
          bestRow = row;
          bestColumn = column;
          bestCandidates = candidates;
        }
      }
    }

    if (bestCandidates == null) return 1;

    var solutions = 0;
    for (final candidate in bestCandidates) {
      board[bestRow][bestColumn] = candidate;
      solutions += search();
      board[bestRow][bestColumn] = 0;
      if (solutions > 1) return solutions;
    }
    return solutions;
  }

  return search();
}

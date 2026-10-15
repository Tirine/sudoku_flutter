import 'dart:async';

import 'package:sudoku_flutter/sudoku.dart';

typedef SudokuFactory = Future<Sudoku> Function(SudokuDifficulty difficulty);

class SudokuPuzzlePool {
  SudokuPuzzlePool({
    required SudokuFactory create,
    this.preloadCount = 3,
  }) : _create = create;

  final SudokuFactory _create;
  final int preloadCount;
  final Map<SudokuDifficulty, List<Future<Sudoku>>> _boards = {
    for (final difficulty in SudokuDifficulty.values) difficulty: [],
  };

  int bufferedCount(SudokuDifficulty difficulty) => _boards[difficulty]!.length;

  void preloadAll() {
    for (final difficulty in SudokuDifficulty.values) {
      _fill(difficulty);
    }
  }

  Future<Sudoku> take(SudokuDifficulty difficulty) async {
    final boards = _boards[difficulty]!;
    if (boards.isEmpty) {
      final board = await _create(difficulty);
      _fill(difficulty);
      return board;
    }

    final board = boards.removeAt(0);
    _fill(difficulty);
    return board;
  }

  void _fill(SudokuDifficulty difficulty) {
    final boards = _boards[difficulty]!;
    while (boards.length < preloadCount) {
      final future = _create(difficulty);
      boards.add(future);
      // Keep background generation errors observable by `take` without
      // allowing an unconsumed preload failure to become an uncaught async error.
      unawaited(
          future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    }
  }
}

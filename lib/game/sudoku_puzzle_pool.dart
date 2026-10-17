import 'dart:async';

import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/utils.dart';

typedef SudokuFactory = Future<SudokuGenerator> Function(
    SudokuDifficulty difficulty, int? seed);

class SudokuPuzzlePool {
  SudokuPuzzlePool({
    required SudokuFactory create,
    this.preloadCount = 3,
    this.maxConcurrentGenerations = 3,
  })  : assert(preloadCount >= 0),
        assert(maxConcurrentGenerations > 0),
        _create = create;

  final SudokuFactory _create;
  final int preloadCount;
  final int maxConcurrentGenerations;
  int _activeGenerations = 0;
  final List<_PendingGeneration> _pendingGenerations = [];
  final Map<SudokuDifficulty, List<Future<SudokuGenerator>>> _boards = {
    for (final difficulty in SudokuDifficulty.values) difficulty: [],
  };

  int bufferedCount(SudokuDifficulty difficulty) => _boards[difficulty]!.length;

  void preload(SudokuDifficulty difficulty) => _fill(difficulty);

  Future<SudokuGenerator> preloadGame(SudokuDifficulty difficulty, int seed) {
    final promise =
        Future<SudokuGenerator>.sync(() => _create(difficulty, seed));
    return promise;
  }

  void preloadAll() {
    for (final difficulty in SudokuDifficulty.values) {
      preload(difficulty);
    }
  }

  Future<SudokuGenerator> take(SudokuDifficulty difficulty) async {
    final boards = _boards[difficulty]!;
    if (boards.isEmpty) {
      final board = await _queueGeneration(difficulty);
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
      final future = _queueGeneration(difficulty);
      boards.add(future);
      // Keep background generation errors observable by `take` without
      // allowing an unconsumed preload failure to become an uncaught async error.
      unawaited(
          future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    }
  }

  Future<SudokuGenerator> _queueGeneration(SudokuDifficulty difficulty) {
    final completer = Completer<SudokuGenerator>();
    _pendingGenerations.add(
      _PendingGeneration(
        difficulty: difficulty,
        completer: completer,
      ),
    );
    _scheduleGenerations();
    return completer.future;
  }

  void _scheduleGenerations() {
    while (_activeGenerations < maxConcurrentGenerations &&
        _pendingGenerations.isNotEmpty) {
      final pending = _pendingGenerations.removeAt(0);
      _activeGenerations++;
      Future<SudokuGenerator>.sync(() => _create(pending.difficulty, null))
          .then(
        pending.completer.complete,
        onError: pending.completer.completeError,
      )
          .whenComplete(() {
        _activeGenerations--;
        _scheduleGenerations();
      });
    }
  }
}

class _PendingGeneration {
  const _PendingGeneration({required this.difficulty, required this.completer});

  final SudokuDifficulty difficulty;
  final Completer<SudokuGenerator> completer;
}

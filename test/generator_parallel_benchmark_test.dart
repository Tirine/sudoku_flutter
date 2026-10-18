import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/game/sudoku_puzzle_pool.dart';

const _reportPath = 'benchmark/results/parallel_latest.json';
const _cases = <({int seed, SudokuDifficulty difficulty})>[
  (seed: 123456, difficulty: SudokuDifficulty.easy),
  (seed: 314159265, difficulty: SudokuDifficulty.easy),
  (seed: 234567, difficulty: SudokuDifficulty.medium),
  (seed: 628318531, difficulty: SudokuDifficulty.medium),
  (seed: 345678, difficulty: SudokuDifficulty.hard),
  (seed: 987654321, difficulty: SudokuDifficulty.hard),
  (seed: 654321, difficulty: SudokuDifficulty.extreme),
  (seed: 789012, difficulty: SudokuDifficulty.extreme),
];

void main() {
  test('sequential and capped parallel generation benchmark', () async {
    final sequentialWatch = Stopwatch()..start();
    final sequential = await Future.wait(
      _cases.map(
        (benchmarkCase) => SudokuGenerator.create(
          seed: benchmarkCase.seed,
          difficulty: benchmarkCase.difficulty,
        ),
      ),
    );
    sequentialWatch.stop();

    final parallelWatch = Stopwatch()..start();
    final parallelCases = List<({int seed, SudokuDifficulty difficulty})>.from(
      _cases,
    );
    final pool = SudokuPuzzlePool(
      preloadCount: 0,
      maxConcurrentGenerations: 2,
      create: (difficulty, s) {
        final nextCase = parallelCases.removeAt(0);
        expect(nextCase.difficulty, difficulty);
        return SudokuGenerator.create(
            seed: nextCase.seed, difficulty: difficulty,);
      },
    );
    final parallel = await Future.wait(
      _cases.map((benchmarkCase) => pool.take(benchmarkCase.difficulty)),
    );
    parallelWatch.stop();

    final outputs = <Map<String, Object>>[];
    for (var index = 0; index < _cases.length; index++) {
      final benchmarkCase = _cases[index];
      final sequentialPuzzle = sequential[index];
      final parallelPuzzle = parallel[index];
      final puzzle = _flatten(sequentialPuzzle.board);
      final solution = _flatten(sequentialPuzzle.solution);
      expect(_flatten(parallelPuzzle.board), puzzle);
      expect(_flatten(parallelPuzzle.solution), solution);
      outputs.add({
        'seed': benchmarkCase.seed,
        'difficulty': benchmarkCase.difficulty.name,
        'clueCount': puzzle.replaceAll('0', '').length,
        'puzzle': puzzle,
        'solution': solution,
      });
    }

    final report = <String, Object>{
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runtime': Platform.version,
      'maxConcurrentGenerations': 2,
      'sequentialElapsedMs': sequentialWatch.elapsedMicroseconds / 1000,
      'cappedParallelElapsedMs': parallelWatch.elapsedMicroseconds / 1000,
      'cases': outputs,
    };
    final file = File(_reportPath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(report)}\n');

    // ignore: avoid_print
    print(
      'Sequential: ${report['sequentialElapsedMs']} ms; '
      'capped parallel (2): ${report['cappedParallelElapsedMs']} ms. '
      'Report: $_reportPath',
    );
  });
}

String _flatten(Board board) => board.expand((row) => row).join();

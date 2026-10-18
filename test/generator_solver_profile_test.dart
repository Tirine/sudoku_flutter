import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';

const _profilePath = 'benchmark/results/solver_profile_latest.json';
const _profileCases = <({int seed, SudokuDifficulty difficulty})>[
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
  test('profiles fixed-seed uniqueness and logical solving costs', () async {
    final cases = <Map<String, Object>>[];

    for (final profileCase in _profileCases) {
      final profile = SudokuGenerationProfile();
      final generator = SudokuGenerator(
        seed: profileCase.seed,
        difficulty: profileCase.difficulty,
        initialise: false,
        profile: profile,
      );
      await generator.init();

      expect(generator.initialised, isTrue);
      expect(generator.seed, profileCase.seed);
      expect(profile.uniquenessChecks, greaterThan(0));
      if (profileCase.difficulty == SudokuDifficulty.extreme) {
        expect(profile.logicalSolveChecks, greaterThan(0));
      } else {
        expect(profile.logicalSolveChecks, 0);
      }

      final uniquenessMs = profile.uniquenessMicroseconds / 1000;
      final logicalSolveMs = profile.logicalSolveMicroseconds / 1000;
      final result = <String, Object>{
        'seed': profileCase.seed,
        'difficulty': profileCase.difficulty.name,
        'generationMs': profile.generationMicroseconds / 1000,
        'uniquenessChecks': profile.uniquenessChecks,
        'uniquenessMs': uniquenessMs,
        'logicalSolveChecks': profile.logicalSolveChecks,
        'logicalSolveMs': logicalSolveMs,
        'otherGenerationMs': (profile.generationMicroseconds / 1000) -
            uniquenessMs -
            logicalSolveMs,
        'puzzle': _flatten(generator.board),
        'solution': _flatten(generator.solution),
      };
      cases.add(result);

      // ignore: avoid_print
      print(
        '${profileCase.difficulty.name.padRight(7)} '
        'seed ${profileCase.seed.toString().padLeft(9)}: '
        '${profile.uniquenessChecks} uniqueness checks '
        '(${uniquenessMs.toStringAsFixed(2)} ms), '
        '${profile.logicalSolveChecks} logical checks '
        '(${logicalSolveMs.toStringAsFixed(2)} ms)',
      );
    }

    final report = <String, Object>{
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runtime': Platform.version,
      'measurement': 'Profiled in-process generation; timings are diagnostic.',
      'cases': cases,
    };
    final file = File(_profilePath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(report)}\n');
    // ignore: avoid_print
    print('Solver profile report: $_profilePath');
  });
}

String _flatten(Board board) => board.expand((row) => row).join();

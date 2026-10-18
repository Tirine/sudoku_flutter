import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';

const _baselinePath = 'benchmark/generator_baseline.json';
const _reportPath = 'benchmark/results/solver_cell_selection_latest.json';
const _iterations = 3;

void main() {
  test('benchmarks row-major and fewest-candidate cell selection', () async {
    final baseline = jsonDecode(await File(_baselinePath).readAsString())
        as Map<String, dynamic>;
    final baselineCases = baseline['cases'] as List<dynamic>;
    final results = <Map<String, Object>>[];

    for (final rawCase in baselineCases) {
      final benchmarkCase = rawCase as Map<String, dynamic>;
      final seed = benchmarkCase['seed'] as int;
      final difficulty = SudokuDifficulty.values.firstWhere(
        (value) => value.name == benchmarkCase['difficulty'],
      );
      final expectedSolution = benchmarkCase['solution'] as String;

      for (final selection in SudokuCellSelection.values) {
        final timingsMs = <double>[];
        int? searchNodes;
        int? candidateAssignments;

        for (var iteration = 0; iteration < _iterations; iteration++) {
          final profile = SudokuGenerationProfile();
          final generator = SudokuGenerator(
            seed: seed,
            difficulty: difficulty,
            cellSelection: selection,
            profile: profile,
            initialise: false,
          );
          final board = _boardFromString(benchmarkCase['puzzle'] as String);
          final stopwatch = Stopwatch()..start();
          final solved = await generator.solver(board);
          stopwatch.stop();

          expect(solved, isTrue);
          expect(_flatten(board), expectedSolution);
          expect(profile.searchNodes, greaterThan(0));
          expect(profile.candidateAssignments, greaterThan(0));

          if (searchNodes != null) {
            expect(profile.searchNodes, searchNodes);
            expect(profile.candidateAssignments, candidateAssignments);
          }
          searchNodes = profile.searchNodes;
          candidateAssignments = profile.candidateAssignments;
          timingsMs.add(stopwatch.elapsedMicroseconds / 1000);
        }

        final sortedTimings = List<double>.from(timingsMs)..sort();
        final result = <String, Object>{
          'seed': seed,
          'difficulty': difficulty.name,
          'selection': selection.name,
          'iterationsMs': timingsMs,
          'medianMs': sortedTimings[sortedTimings.length ~/ 2],
          'searchNodes': searchNodes!,
          'candidateAssignments': candidateAssignments!,
          'solution': expectedSolution,
        };
        results.add(result);

        // ignore: avoid_print
        print(
          '${difficulty.name.padRight(7)} '
          'seed ${seed.toString().padLeft(9)} '
          '${selection.name.padRight(16)} '
          '${result['medianMs']} ms, '
          '$searchNodes nodes, $candidateAssignments assignments',
        );
      }
    }

    final report = <String, Object>{
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runtime': Platform.version,
      'method':
          'Three deterministic solves per strategy for each stored puzzle.',
      'cases': results,
    };
    final file = File(_reportPath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(report)}\n');
    // ignore: avoid_print
    print('Cell-selection report: $_reportPath');
  });
}

Board _boardFromString(String values) => [
      for (var row = 0; row < 9; row++)
        [
          for (var column = 0; column < 9; column++)
            int.parse(values[row * 9 + column]),
        ],
    ];

String _flatten(Board board) => board.expand((row) => row).join();

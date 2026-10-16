import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/sudoku.dart';

const _baselinePath = 'benchmark/generator_baseline.json';
const _latestReportPath = 'benchmark/results/latest.json';
const _iterationsPerCase = 3;
const _updateBaseline = bool.fromEnvironment('UPDATE_GENERATOR_BASELINE');
const _benchmarkCases = <({int seed, SudokuDifficulty difficulty})>[
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
  test('fixed-seed generator benchmark matches the stored baseline', () async {
    final cases = <Map<String, Object>>[];
    for (final benchmarkCase in _benchmarkCases) {
      final timingsMs = <double>[];
      Sudoku? puzzle;
      for (var iteration = 0; iteration < _iterationsPerCase; iteration++) {
        final stopwatch = Stopwatch()..start();
        final generated = await Sudoku.create(
          seed: benchmarkCase.seed,
          difficulty: benchmarkCase.difficulty,
        );
        stopwatch.stop();
        _validateGeneratedPuzzle(generated);

        if (puzzle != null) {
          expect(
            _flatten(generated.board),
            _flatten(puzzle.board),
            reason: 'Seed ${benchmarkCase.seed} should be reproducible.',
          );
          expect(
            _flatten(generated.solution),
            _flatten(puzzle.solution),
            reason:
                'Seed ${benchmarkCase.seed} solution should be reproducible.',
          );
        }
        puzzle = generated;
        timingsMs.add(stopwatch.elapsedMicroseconds / 1000);
      }

      final sortedTimings = List<double>.from(timingsMs)..sort();
      final medianMs = sortedTimings[sortedTimings.length ~/ 2];
      final generatedPuzzle = puzzle!;
      final result = <String, Object>{
        'seed': benchmarkCase.seed,
        'difficulty': benchmarkCase.difficulty.name,
        'iterationsMs': timingsMs,
        'medianGenerationMs': medianMs,
        'clueCount': _clueCount(generatedPuzzle.board),
        'puzzle': _flatten(generatedPuzzle.board),
        'solution': _flatten(generatedPuzzle.solution),
      };
      cases.add(result);
      // ignore: avoid_print
      print(
        '${benchmarkCase.difficulty.name.padRight(7)} '
        'seed ${benchmarkCase.seed.toString().padLeft(9)}: '
        '$medianMs ms median (${timingsMs.join(', ')}), '
        '${result['clueCount']} clues',
      );
    }

    final report = <String, Object>{
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runtime': Platform.version,
      'cases': cases,
    };
    await _writeJson(_latestReportPath, report);

    if (_updateBaseline) {
      await _writeJson(_baselinePath, report);
      // ignore: avoid_print
      print('Updated benchmark baseline: $_baselinePath');
      return;
    }

    final baselineFile = File(_baselinePath);
    expect(
      await baselineFile.exists(),
      isTrue,
      reason: 'Create a baseline with UPDATE_GENERATOR_BASELINE=true first.',
    );
    final baseline =
        jsonDecode(await baselineFile.readAsString()) as Map<String, dynamic>;
    final baselineCases = {
      for (final entry in baseline['cases'] as List<dynamic>)
        _caseKey(entry as Map<String, dynamic>): entry,
    };
    final mismatches = <String>[];
    for (final result in cases) {
      final key = _caseKey(result);
      final expected = baselineCases[key];
      if (expected == null ||
          expected['puzzle'] != result['puzzle'] ||
          expected['solution'] != result['solution'] ||
          expected['clueCount'] != result['clueCount']) {
        mismatches.add(key);
      }
    }

    expect(
      mismatches,
      isEmpty,
      reason: 'Seeded outputs differ from the baseline. Review changes before '
          'updating it. Mismatches: ${mismatches.join(', ')}',
    );
    expect(baselineCases.length, cases.length);
    // ignore: avoid_print
    print('Seeded outputs match the baseline.');
    // ignore: avoid_print
    print('Latest timing report: $_latestReportPath');
  });
}

String _caseKey(Map<String, dynamic> entry) =>
    '${entry['difficulty']}:${entry['seed']}';

Future<void> _writeJson(String path, Map<String, Object> contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(contents)}\n');
}

void _validateGeneratedPuzzle(Sudoku puzzle) {
  expect(
    _isCompleteSolution(puzzle.solution),
    isTrue,
    reason: 'Seed ${puzzle.seed} should generate a valid solution.',
  );

  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 9; column++) {
      final clue = puzzle.board[row][column];
      expect(clue, inInclusiveRange(0, 9));
      if (clue != 0) {
        expect(
          clue,
          puzzle.solution[row][column],
          reason:
              'Seed ${puzzle.seed} has a clue that conflicts with its solution.',
        );
      }
    }
  }

  expect(
    _countSolutions(puzzle.board),
    1,
    reason: 'Seed ${puzzle.seed} should generate a unique puzzle.',
  );
}

bool _isCompleteSolution(Board board) {
  if (board.length != 9 || board.any((row) => row.length != 9)) return false;
  const digits = {1, 2, 3, 4, 5, 6, 7, 8, 9};

  for (var index = 0; index < 9; index++) {
    final row = board[index].toSet();
    final column = {for (var row = 0; row < 9; row++) board[row][index]};
    if (row.length != 9 ||
        !row.containsAll(digits) ||
        column.length != 9 ||
        !column.containsAll(digits)) {
      return false;
    }
  }

  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxColumn = 0; boxColumn < 3; boxColumn++) {
      final box = {
        for (var row = boxRow * 3; row < boxRow * 3 + 3; row++)
          for (var column = boxColumn * 3; column < boxColumn * 3 + 3; column++)
            board[row][column],
      };
      if (box.length != 9 || !box.containsAll(digits)) return false;
    }
  }
  return true;
}

int _countSolutions(Board source) {
  final board = Sudoku.cloneBoard(source);
  final rows = List<int>.filled(9, 0);
  final columns = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);

  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 9; column++) {
      final value = board[row][column];
      if (value == 0) continue;
      if (value < 1 || value > 9) return 0;
      final bit = 1 << value;
      final box = (row ~/ 3) * 3 + column ~/ 3;
      if ((rows[row] & bit) != 0 ||
          (columns[column] & bit) != 0 ||
          (boxes[box] & bit) != 0) {
        return 0;
      }
      rows[row] |= bit;
      columns[column] |= bit;
      boxes[box] |= bit;
    }
  }

  int search() {
    var bestRow = -1;
    var bestColumn = -1;
    var bestMask = 0;
    var bestCount = 10;

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (board[row][column] != 0) continue;
        final box = (row ~/ 3) * 3 + column ~/ 3;
        final used = rows[row] | columns[column] | boxes[box];
        var mask = 0;
        var count = 0;
        for (var digit = 1; digit <= 9; digit++) {
          final bit = 1 << digit;
          if ((used & bit) == 0) {
            mask |= bit;
            count++;
          }
        }
        if (count == 0) return 0;
        if (count < bestCount) {
          bestRow = row;
          bestColumn = column;
          bestMask = mask;
          bestCount = count;
        }
      }
    }

    if (bestRow == -1) return 1;
    final box = (bestRow ~/ 3) * 3 + bestColumn ~/ 3;
    var solutions = 0;
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      if ((bestMask & bit) == 0) continue;
      board[bestRow][bestColumn] = digit;
      rows[bestRow] |= bit;
      columns[bestColumn] |= bit;
      boxes[box] |= bit;
      solutions += search();
      board[bestRow][bestColumn] = 0;
      rows[bestRow] &= ~bit;
      columns[bestColumn] &= ~bit;
      boxes[box] &= ~bit;
      if (solutions > 1) return solutions;
    }
    return solutions;
  }

  return search();
}

int _clueCount(Board board) =>
    board.expand((row) => row).where((value) => value != 0).length;

String _flatten(Board board) => board.expand((row) => row).join();

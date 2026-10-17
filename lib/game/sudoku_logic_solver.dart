import 'package:sudoku_flutter/game/sudoku_generator.dart';

/// Solves puzzles using deterministic candidate techniques only.
///
/// This deliberately does not search or backtrack. A false result means the
/// puzzle needs a technique this solver does not implement (or is invalid).
class SudokuLogicSolver {
  bool canSolve(Board source) {
    if (source.length != 9 || source.any((row) => row.length != 9)) {
      return false;
    }
    final board = SudokuGenerator.cloneBoard(source);

    while (true) {
      var candidates = _candidatesFor(board);
      if (candidates == null) return false;

      var placed = _placeSingle(board, candidates);
      if (placed) continue;

      while (true) {
        if (!_hasCandidates(candidates)) return true;

        if (_applyLockedCandidates(candidates) ||
            _applyNakedPairs(candidates) ||
            _applyXWing(candidates)) {
          if (!_candidatesAreValid(board, candidates)) return false;
          placed = _placeSingle(board, candidates);
          if (placed) break;
          continue;
        }

        return false;
      }
    }
  }

  List<List<Set<int>>>? _candidatesFor(Board board) {
    final candidates = List.generate(
      9,
      (_) => List.generate(9, (_) => <int>{}),
    );

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        final value = board[row][column];
        if (value < 0 || value > 9) return null;
        if (value == 0) {
          for (var digit = 1; digit <= 9; digit++) {
            if (SudokuGenerator.isValidCell(board, row, column, digit)) {
              candidates[row][column].add(digit);
            }
          }
          if (candidates[row][column].isEmpty) return null;
        } else {
          final withoutCell = SudokuGenerator.cloneBoard(board);
          withoutCell[row][column] = 0;
          if (!SudokuGenerator.isValidCell(withoutCell, row, column, value)) {
            return null;
          }
        }
      }
    }
    return candidates;
  }

  bool _placeSingle(Board board, List<List<Set<int>>> candidates) {
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (board[row][column] == 0 && candidates[row][column].length == 1) {
          board[row][column] = candidates[row][column].first;
          return true;
        }
      }
    }

    for (final unit in _units()) {
      for (var digit = 1; digit <= 9; digit++) {
        final locations = unit
            .where((cell) =>
                board[cell.$1][cell.$2] == 0 &&
                candidates[cell.$1][cell.$2].contains(digit))
            .toList();
        if (locations.length == 1) {
          final (row, column) = locations.single;
          board[row][column] = digit;
          return true;
        }
      }
    }
    return false;
  }

  bool _applyLockedCandidates(List<List<Set<int>>> candidates) {
    var changed = false;
    final original = _copyCandidates(candidates);

    // Pointing: if a box's candidates for a digit share a row or column,
    // remove that digit from the rest of that row or column.
    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxColumn = 0; boxColumn < 3; boxColumn++) {
        final cells = [
          for (var row = boxRow * 3; row < boxRow * 3 + 3; row++)
            for (var column = boxColumn * 3;
                column < boxColumn * 3 + 3;
                column++)
              (row, column),
        ];
        for (var digit = 1; digit <= 9; digit++) {
          final positions = cells
              .where((cell) => original[cell.$1][cell.$2].contains(digit))
              .toList();
          if (positions.isEmpty) continue;

          final rows = positions.map((cell) => cell.$1).toSet();
          if (rows.length == 1) {
            final row = rows.single;
            for (var column = 0; column < 9; column++) {
              if (column ~/ 3 != boxColumn) {
                changed |= candidates[row][column].remove(digit);
              }
            }
          }

          final columns = positions.map((cell) => cell.$2).toSet();
          if (columns.length == 1) {
            final column = columns.single;
            for (var row = 0; row < 9; row++) {
              if (row ~/ 3 != boxRow) {
                changed |= candidates[row][column].remove(digit);
              }
            }
          }
        }
      }
    }

    // Claiming: if a row or column's candidates are in one box, remove the
    // digit from the other cells in that box.
    for (var index = 0; index < 9; index++) {
      for (var digit = 1; digit <= 9; digit++) {
        final rowPositions = [
          for (var column = 0; column < 9; column++)
            if (original[index][column].contains(digit)) column,
        ];
        if (rowPositions.isNotEmpty &&
            rowPositions.map((column) => column ~/ 3).toSet().length == 1) {
          final boxColumn = rowPositions.first ~/ 3;
          for (var row = (index ~/ 3) * 3; row < (index ~/ 3) * 3 + 3; row++) {
            if (row != index) {
              for (var column = boxColumn * 3;
                  column < boxColumn * 3 + 3;
                  column++) {
                changed |= candidates[row][column].remove(digit);
              }
            }
          }
        }

        final columnPositions = [
          for (var row = 0; row < 9; row++)
            if (original[row][index].contains(digit)) row,
        ];
        if (columnPositions.isNotEmpty &&
            columnPositions.map((row) => row ~/ 3).toSet().length == 1) {
          final boxRow = columnPositions.first ~/ 3;
          for (var row = boxRow * 3; row < boxRow * 3 + 3; row++) {
            for (var column = (index ~/ 3) * 3;
                column < (index ~/ 3) * 3 + 3;
                column++) {
              if (column != index) {
                changed |= candidates[row][column].remove(digit);
              }
            }
          }
        }
      }
    }
    return changed;
  }

  bool _applyNakedPairs(List<List<Set<int>>> candidates) {
    var changed = false;
    final original = _copyCandidates(candidates);
    for (final unit in _units()) {
      final pairs = <String, List<(int, int)>>{};
      for (final (row, column) in unit) {
        final values = original[row][column];
        if (values.length == 2) {
          final key = (values.toList()..sort()).join(',');
          pairs.putIfAbsent(key, () => []).add((row, column));
        }
      }

      for (final entry in pairs.entries) {
        if (entry.value.length != 2) continue;
        final digits = entry.key.split(',').map(int.parse).toSet();
        for (final (row, column) in unit) {
          if (entry.value.contains((row, column))) continue;
          for (final digit in digits) {
            changed |= candidates[row][column].remove(digit);
          }
        }
      }
    }
    return changed;
  }

  bool _applyXWing(List<List<Set<int>>> candidates) {
    var changed = false;
    final original = _copyCandidates(candidates);
    for (var digit = 1; digit <= 9; digit++) {
      final rowsByColumns = <String, List<int>>{};
      for (var row = 0; row < 9; row++) {
        final columns = [
          for (var column = 0; column < 9; column++)
            if (original[row][column].contains(digit)) column,
        ];
        if (columns.length == 2) {
          rowsByColumns.putIfAbsent(columns.join(','), () => []).add(row);
        }
      }
      for (final entry in rowsByColumns.entries) {
        if (entry.value.length != 2) continue;
        final columns = entry.key.split(',').map(int.parse).toList();
        for (var row = 0; row < 9; row++) {
          if (entry.value.contains(row)) continue;
          for (final column in columns) {
            changed |= candidates[row][column].remove(digit);
          }
        }
      }

      final columnsByRows = <String, List<int>>{};
      for (var column = 0; column < 9; column++) {
        final rows = [
          for (var row = 0; row < 9; row++)
            if (original[row][column].contains(digit)) row,
        ];
        if (rows.length == 2) {
          columnsByRows.putIfAbsent(rows.join(','), () => []).add(column);
        }
      }
      for (final entry in columnsByRows.entries) {
        if (entry.value.length != 2) continue;
        final rows = entry.key.split(',').map(int.parse).toList();
        for (var column = 0; column < 9; column++) {
          if (entry.value.contains(column)) continue;
          for (final row in rows) {
            changed |= candidates[row][column].remove(digit);
          }
        }
      }
    }
    return changed;
  }

  bool _candidatesAreValid(
    Board board,
    List<List<Set<int>>> candidates,
  ) {
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        if (board[row][column] == 0 && candidates[row][column].isEmpty) {
          return false;
        }
      }
    }
    for (final unit in _units()) {
      for (var digit = 1; digit <= 9; digit++) {
        final alreadyPlaced = unit.any(
          (cell) => board[cell.$1][cell.$2] == digit,
        );
        final stillPossible = unit.any(
          (cell) => candidates[cell.$1][cell.$2].contains(digit),
        );
        if (!alreadyPlaced && !stillPossible) return false;
      }
    }
    return true;
  }

  List<List<Set<int>>> _copyCandidates(List<List<Set<int>>> candidates) =>
      candidates
          .map((row) => row.map((cell) => Set<int>.from(cell)).toList())
          .toList();

  bool _hasCandidates(List<List<Set<int>>> candidates) =>
      candidates.any((row) => row.any((cell) => cell.isNotEmpty));

  List<List<(int, int)>> _units() => [
        for (var row = 0; row < 9; row++)
          [
            (row, 0),
            (row, 1),
            (row, 2),
            (row, 3),
            (row, 4),
            (row, 5),
            (row, 6),
            (row, 7),
            (row, 8)
          ],
        for (var column = 0; column < 9; column++)
          [
            (0, column),
            (1, column),
            (2, column),
            (3, column),
            (4, column),
            (5, column),
            (6, column),
            (7, column),
            (8, column)
          ],
        for (var boxRow = 0; boxRow < 3; boxRow++)
          for (var boxColumn = 0; boxColumn < 3; boxColumn++)
            [
              for (var row = boxRow * 3; row < boxRow * 3 + 3; row++)
                for (var column = boxColumn * 3;
                    column < boxColumn * 3 + 3;
                    column++)
                  (row, column),
            ],
      ];
}

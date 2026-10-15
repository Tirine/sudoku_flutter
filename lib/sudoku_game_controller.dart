import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sudoku_flutter/sudoku.dart';

/// Owns the mutable state for one Sudoku game, independently of its widgets.
class SudokuGameController extends ChangeNotifier {
  SudokuGameController({required Sudoku initialGame, bool startTimer = true}) {
    load(initialGame, startTimer: startTimer);
  }

  late Sudoku game;
  late List<List<bool>> _editable;
  late List<List<Set<int>>> _notes;
  int selectedRow = -1;
  int selectedCol = -1;
  int selectedNumber = -1;
  int elapsedSeconds = 0;
  bool notesEnabled = false;
  bool _isComplete = false;
  bool get isComplete => _isComplete;
  Timer? _timer;

  bool isEditable(int row, int column) => _editable[row][column];
  Set<int> notesAt(int row, int column) => _notes[row][column];
  int valueAt(int row, int column) => game.board[row][column];
  bool get isFilled => game.filled();

  void load(Sudoku nextGame, {bool startTimer = true}) {
    _timer?.cancel();
    game = nextGame;
    _editable = List.generate(
      9,
      (row) => List.generate(9, (column) => nextGame.board[row][column] == 0),
    );
    _notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
    selectedRow = -1;
    selectedCol = -1;
    selectedNumber = -1;
    elapsedSeconds = 0;
    notesEnabled = false;
    _isComplete = false;
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isComplete) {
          elapsedSeconds++;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void toggleNotes(bool enabled) {
    if (_isComplete) return;
    notesEnabled = enabled;
    notifyListeners();
  }

  void selectCell(int row, int column) {
    if (!isEditable(row, column) || _isComplete) return;
    if (selectedNumber >= 0) {
      _setCell(row, column, selectedNumber);
    } else if (selectedRow == row && selectedCol == column) {
      selectedRow = -1;
      selectedCol = -1;
    } else {
      selectedRow = row;
      selectedCol = column;
    }
    notifyListeners();
  }

  void selectNumber(int number) {
    if (_isComplete) return;
    if (selectedRow >= 0) {
      _setCell(selectedRow, selectedCol, number);
    } else {
      selectedNumber = selectedNumber == number ? -1 : number;
    }
    notifyListeners();
  }

  bool verifyAndComplete() {
    if (_isComplete || !game.filled() || !game.verify()) return false;
    _isComplete = true;
    _timer?.cancel();
    notifyListeners();
    return true;
  }

  void _setCell(int row, int column, int number) {
    if (!_editable[row][column] || _isComplete) return;
    if (notesEnabled) {
      if (number == 0) {
        _notes[row][column].clear();
      } else if (!_notes[row][column].add(number)) {
        _notes[row][column].remove(number);
      }
      return;
    }

    game.board[row][column] = number;
    _notes[row][column].clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

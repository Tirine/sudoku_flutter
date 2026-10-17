import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';

/// Owns the mutable state for one Sudoku game, independently of its widgets.
class SudokuGameController extends ChangeNotifier {
  static const maxUndoSteps = 3;
  SudokuGameController(
      {required SudokuGenerator initialGame, bool startTimer = true}) {
    load(initialGame, startTimer: startTimer);
  }

  late SudokuGenerator game;
  late List<List<bool>> _editable;
  late List<List<Set<int>>> _notes;
  final List<_GameProgress> _undoHistory = [];
  int selectedRow = -1;
  int selectedCol = -1;
  int selectedNumber = -1;
  int elapsedSeconds = 0;
  bool notesEnabled = false;
  bool _isComplete = false;
  bool _timerEnabled = false;
  bool get isComplete => _isComplete;
  bool get canUndo => _undoHistory.isNotEmpty && !_isComplete;
  Timer? _timer;

  bool isEditable(int row, int column) => _editable[row][column];
  Set<int> notesAt(int row, int column) => _notes[row][column];
  int valueAt(int row, int column) => game.board[row][column];
  bool get isFilled => game.filled();

  void load(SudokuGenerator nextGame, {bool startTimer = true}) {
    _timer?.cancel();
    game = nextGame;
    _editable = List.generate(
      9,
      (row) => List.generate(9, (column) => nextGame.board[row][column] == 0),
    );
    _notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
    _undoHistory.clear();
    selectedRow = -1;
    selectedCol = -1;
    selectedNumber = -1;
    elapsedSeconds = 0;
    notesEnabled = false;
    _isComplete = false;
    _timerEnabled = startTimer;
    if (_timerEnabled) _startTimer();
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void resumeTimer() {
    if (_timerEnabled && !_isComplete && _timer == null) _startTimer();
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

  void undo() {
    if (!canUndo) return;
    final previous = _undoHistory.removeLast();
    _copyBoardInto(previous.board, game.board);
    _copyNotes(previous.notes, _notes);
    notifyListeners();
  }

  Map<String, Object> exportProgress() => {
        'seed': game.seed,
        'difficulty': game.difficulty.name,
        'board': _copyBoard(game.board),
        'notes': _serializeNotes(_notes),
        'elapsedSeconds': elapsedSeconds,
        'undoHistory': _undoHistory.map((entry) => entry.toJson()).toList(),
      };

  void restoreProgress(Map<String, dynamic> progress) {
    final board = _parseBoard(progress['board']);
    final notes = _parseNotes(progress['notes']);
    final elapsed = progress['elapsedSeconds'];
    final history = progress['undoHistory'];
    if (elapsed is! int || elapsed < 0 || history is! List) {
      throw const FormatException('Invalid saved game progress.');
    }
    _copyBoardInto(board, game.board);
    _copyNotes(notes, _notes);
    _undoHistory
      ..clear()
      ..addAll(
        (history.length > maxUndoSteps
                ? history.skip(history.length - maxUndoSteps)
                : history)
            .map(_GameProgress.fromJson),
      );
    elapsedSeconds = elapsed;
    _isComplete = false;
    _timerEnabled = true;
    _timer?.cancel();
    _startTimer();
    notifyListeners();
  }

  bool verifyAndComplete() {
    if (_isComplete || !game.filled() || !game.verify()) return false;
    _isComplete = true;
    _timerEnabled = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
    return true;
  }

  void _setCell(int row, int column, int number) {
    if (!_editable[row][column] || _isComplete) return;
    final before = _GameProgress.fromGame(game.board, _notes);
    if (notesEnabled) {
      if (number == 0) {
        if (_notes[row][column].isEmpty) return;
        _notes[row][column].clear();
      } else if (!_notes[row][column].add(number)) {
        _notes[row][column].remove(number);
      }
      _recordUndo(before);
      return;
    }
    if (game.board[row][column] == number && _notes[row][column].isEmpty) {
      return;
    }
    game.board[row][column] = number;
    _notes[row][column].clear();
    _recordUndo(before);
  }

  void _recordUndo(_GameProgress progress) {
    _undoHistory.add(progress);
    if (_undoHistory.length > maxUndoSteps) _undoHistory.removeAt(0);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isComplete) {
        elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  static Board _copyBoard(List<List<int>> source) =>
      source.map((row) => List<int>.from(row)).toList();

  static void _copyBoardInto(Board source, Board target) {
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        target[row][column] = source[row][column];
      }
    }
  }

  static void _copyNotes(
    List<List<Set<int>>> source,
    List<List<Set<int>>> target,
  ) {
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        target[row][column]
          ..clear()
          ..addAll(source[row][column]);
      }
    }
  }

  static List<List<Object>> _serializeNotes(List<List<Set<int>>> notes) => notes
      .map((row) => row.map((cell) => cell.toList()..sort()).toList())
      .toList();

  static Board _parseBoard(dynamic value) {
    if (value is! List ||
        value.length != 9 ||
        value.any((row) =>
            row is! List ||
            row.length != 9 ||
            row.any((cell) => cell is! int || cell < 0 || cell > 9))) {
      throw const FormatException('Invalid saved Sudoku board.');
    }
    return value.map((row) => List<int>.from(row as List)).toList();
  }

  static List<List<Set<int>>> _parseNotes(dynamic value) {
    if (value is! List ||
        value.length != 9 ||
        value.any((row) =>
            row is! List ||
            row.length != 9 ||
            row.any((cell) =>
                cell is! List ||
                cell.any((note) => note is! int || note < 1 || note > 9)))) {
      throw const FormatException('Invalid saved Sudoku notes.');
    }
    return value
        .map((row) =>
            (row as List).map((cell) => Set<int>.from(cell as List)).toList())
        .toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _GameProgress {
  _GameProgress(this.board, this.notes);

  final Board board;
  final List<List<Set<int>>> notes;

  factory _GameProgress.fromGame(Board board, List<List<Set<int>>> notes) =>
      _GameProgress(
        SudokuGameController._copyBoard(board),
        notes
            .map((row) => row.map((cell) => Set<int>.from(cell)).toList())
            .toList(),
      );

  factory _GameProgress.fromJson(dynamic json) {
    if (json is! Map) throw const FormatException('Invalid undo history.');
    return _GameProgress(
      SudokuGameController._parseBoard(json['board']),
      SudokuGameController._parseNotes(json['notes']),
    );
  }

  Map<String, Object> toJson() => {
        'board': SudokuGameController._copyBoard(board),
        'notes': SudokuGameController._serializeNotes(notes),
      };
}

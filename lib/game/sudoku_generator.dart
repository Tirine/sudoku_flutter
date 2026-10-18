import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:sudoku_flutter/utils.dart';

typedef Board = List<List<int>>;

enum SudokuDifficulty { easy, medium, hard, extreme }

enum SudokuCellSelection { rowMajor, fewestCandidates }

class SudokuGenerator {
  static const _noValue = 0;
  static const _boardSize = 9;
  static const _boxSize = 3;
  static const _randMax = 1 << 32;
  static const _minimumClues = 17;
  static const _initialMaxDepth = 5000;
  static const _specialSeedDiagonals = <int, List<int>>{
    314159265: [3, 1, 4, 1, 5, 9, 2, 6, 5],
    628318531: [6, 2, 8, 3, 1, 8, 5, 3, 1],
    123456789: [1, 2, 3, 4, 5, 6, 7, 8, 9],
    987654321: [9, 8, 7, 6, 5, 4, 3, 2, 1],
    241421356: [2, 4, 1, 4, 2, 1, 3, 5, 6],
    915965594: [9, 1, 5, 9, 6, 5, 5, 9, 4],
  };

  final SudokuDifficulty _difficulty;
  bool _initialised = false;
  int _seed;
  late int Function() _random;
  Board _sudoku = createEmpty();
  Board _solution = createEmpty();
  final Board _uniquenessBoard = createEmpty();
  final SudokuGenerationProfile? profile;
  final SudokuCellSelection _cellSelection;
  final _SolverProgress _uniquenessProgress;

  static int _returnZero() => 0;

  static Future<SudokuGenerator> create({
    int? seed,
    SudokuDifficulty difficulty = SudokuDifficulty.easy,
  }) async {
    final obj = await Isolate.run(() async {
      final SudokuGenerator created = SudokuGenerator(
        seed: seed ?? -1,
        difficulty: difficulty,
        initialise: false,
      );
      await created.init();
      return {
        'seed': created.seed,
        'initialised': created._initialised,
        'solution': created.solution,
        'sudoku': created._sudoku,
      };
    });
    final returnVal = SudokuGenerator._(
      obj['seed'] as int,
      difficulty,
      obj['initialised'] as bool,
      obj['solution'] as Board,
      obj['sudoku'] as Board,
    );
    printSudoku(returnVal._solution);
    return returnVal;
  }

  static Board createEmpty() => Board.generate(
        9,
        (index) => List<int>.generate(9, (index) => 0, growable: false),
        growable: false,
      );

  static void _printLine() {
    printDebug('-+ -+ -+ -+ -+ -+ -+ -+ -+ ');
  }

  static void printSudoku(Board board) {
    for (int row = 0; row < board.length; row++) {
      if (row % 3 == 0) {
        _printLine();
      }
      printDebug(_formatRow(board[row]));
    }
    _printLine();
  }

  static String _formatRow(List<int> row) {
    final output = StringBuffer();
    for (int column = 0; column < row.length; column++) {
      if (column % _boxSize == 0) output.write(': ');
      output.write(row[column] == _noValue ? ' . ' : '${row[column]} ');
    }
    return '$output:';
  }

  static bool isValidCell(Board board, int row, int col, int value) {
    final boxRow = row ~/ _boxSize * _boxSize;
    final boxColumn = col ~/ _boxSize * _boxSize;
    for (int index = 0; index < _boardSize; index++) {
      if (board[row][index] == value ||
          board[index][col] == value ||
          board[boxRow + index ~/ _boxSize][boxColumn + index % _boxSize] ==
              value) {
        return false;
      }
    }
    return true;
  }

  static Board cloneBoard(Board obj) {
    return obj.map(List<int>.from).toList(growable: false);
  }

  static void _copyBoardInto(Board source, Board destination) {
    for (var row = 0; row < source.length; row++) {
      for (var column = 0; column < source[row].length; column++) {
        destination[row][column] = source[row][column];
      }
    }
  }

  SudokuGenerator({
    int seed = -1,
    SudokuDifficulty difficulty = SudokuDifficulty.easy,
    SudokuCellSelection cellSelection = SudokuCellSelection.rowMajor,
    this.profile,
    bool initialise = true,
  })  : _difficulty = difficulty,
        _seed = seed,
        _cellSelection = cellSelection,
        _uniquenessProgress = _SolverProgress(profile: profile) {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }

    _random = mulberry32(_offsetSeed());
    if (initialise) {
      unawaited(init());
    }
  }
  SudokuGenerator._(
    this._seed,
    this._difficulty,
    this._initialised,
    this._solution,
    this._sudoku,
  )   : profile = null,
        _cellSelection = SudokuCellSelection.rowMajor,
        _uniquenessProgress = _SolverProgress() {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }
    _random = mulberry32(_offsetSeed());
  }

  int Function() mulberry32(int a) {
    int t;
    return () {
      t = a += 0x6D2B79F5;
      t = (t ^ t >>> 15) * (t | 1);
      t ^= t + ((t ^ t >> 7) * (t | 61));
      return ((t ^ t >> 14) >>> 0).toUnsigned(32);
    };
  }
  // const randomFract = mulberry32(seed);

  int _offsetSeed() {
    return seed + (314159 * _difficulty.index);
  }

  Future<void> init() async {
    profile?.startGeneration();
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }
    _random = mulberry32(_offsetSeed());
    _initialised = true;

    final sudoku = _createSeedBoard();
    final seedBoard = cloneBoard(sudoku);
    while (!(await solver(sudoku, offset: _rand))) {
      _copyBoardInto(seedBoard, sudoku);
    }
    final solution = cloneBoard(sudoku);
    _sudoku = await _removeClues(
      sudoku,
      solution,
      minFilled: _minimumClueCount(),
    );
    _solution = solution;
    profile?.finishGeneration();
  }

  Board _createSeedBoard() {
    final sudoku = createEmpty();
    _applySmallSeedPattern(sudoku);
    _applySpecialSeedPattern(sudoku);
    return sudoku;
  }

  void _applySmallSeedPattern(Board board) {
    if (_seed >= 100) return;

    final pattern = _seed ~/ 25;
    final choose = _rand() - 1;
    final direction = _rand().isEven ? -1 : 1;
    final upDown = pattern == 3 ? (_rand().isEven ? -1 : 1) : null;

    for (var index = 1; index <= 9; index++) {
      final digit = (10 + index * direction) % 10;
      switch (pattern) {
        case 0:
          board[choose][index - 1] = digit;
          break;
        case 1:
          board[index - 1][choose] = digit;
          break;
        case 2:
          final row = (choose % 3) * 3 + ((index - 1) / 3).floor();
          final column = (choose ~/ 3) * 3 + (index - 1) % 3;
          board[row][column] = digit;
          break;
        default:
          final row = (upDown! * index - 1 + choose) % 9;
          board[row][index - 1] = digit;
      }
    }
  }

  void _applySpecialSeedPattern(Board board) {
    final diagonal = _specialSeedDiagonals[_seed];
    if (diagonal == null) return;

    for (var index = 0; index < diagonal.length; index++) {
      board[index][index] = diagonal[index];
    }
  }

  int _minimumClueCount() {
    switch (_difficulty) {
      case SudokuDifficulty.easy:
        return _minimumClues + 32;
      case SudokuDifficulty.medium:
        return _minimumClues + 24;
      case SudokuDifficulty.hard:
        return _minimumClues + 16;
      case SudokuDifficulty.extreme:
        return _minimumClues;
    }
  }

  Future<Board> _removeClues(
    Board sudoku,
    Board solution, {
    required int minFilled,
  }) async {
    var maxDepth = _initialMaxDepth;
    while (true) {
      try {
        final generated = _generateBoard(
          sudoku,
          maxDepth: maxDepth,
          minFilled: minFilled,
        );
        if (generated) return sudoku;
      } catch (e) {
        maxDepth *= 2;
        printDebug('Retry...');
        _copyBoardInto(solution, sudoku);
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  SudokuDifficulty get difficulty => _difficulty;
  int get seed => _seed;
  bool get initialised => _initialised;

  Board get board => _sudoku;

  Board get solution => _solution;

  int _rand() {
    return (_random() % 9) + 1;
  }

  bool verifyCell(int row, int column) {
    return _sudoku[row][column] == _solution[row][column];
  }

  bool filled() {
    for (var r = 0; r < _sudoku.length; r++) {
      for (var c = 0; c < _sudoku[r].length; c++) {
        if (_sudoku[r][c] == 0) return false;
      }
    }
    return true;
  }

  bool verify() {
    for (var r = 0; r < _sudoku.length; r++) {
      for (var c = 0; c < _sudoku[r].length; c++) {
        if (!verifyCell(r, c)) return false;
      }
    }
    return true;
  }

  bool _generateBoard(
    Board board, {
    int minFilled = 0,
    int maxDepth = 20000,
  }) {
    var rowI = _rand() - 1;
    var colI = _rand() - 1;
    void next() {
      rowI += 1;
      if (rowI == _boardSize) {
        rowI %= _boardSize;
        colI = (colI + 1) % _boardSize;
      }
    }

    var filled = _boardSize * _boardSize;

    for (int i = 0; i <= _boardSize; i++) {
      for (int j = 0; j <= _boardSize; j++) {
        if (_tryRemoveClue(
          board,
          rowI,
          colI,
          maxDepth: maxDepth,
        )) {
          filled--;
          rowI = _rand() - 1;
          colI = _rand() - 1;
          i = 0;
          j = 0;
        } else {
          next();
        }
        if (filled <= minFilled) {
          return true;
        }
      }
    }
    return true;
  }

  bool _tryRemoveClue(
    Board board,
    int row,
    int column, {
    required int maxDepth,
  }) {
    if (board[row][column] == _noValue) return false;

    profile?.startUniquenessCheck();
    final isUnique = _isUniqueCell(
      board,
      row,
      column,
      offset: _rand,
      maxDepth: maxDepth,
    );
    profile?.finishUniquenessCheck();
    if (!isUnique) {
      return false;
    }

    board[row][column] = _noValue;
    return true;
  }

  Future<bool> solver(
    Board data, {
    int Function() offset = _returnZero,
    int maxDepth = 0,
  }) async {
    return _solveBoard(
      data,
      offset,
      maxDepth,
      _SolverProgress(profile: profile),
    );
  }

  bool _solveBoard(
    Board board,
    int Function() offset,
    int maxDepth,
    _SolverProgress progress,
  ) {
    if (maxDepth > 1000 && progress.visitedCandidates > maxDepth) {
      throw 'Went too deep';
    }
    final profile = progress.profile;
    if (profile != null) profile.searchNodes++;

    if (_cellSelection == SudokuCellSelection.rowMajor) {
      for (var row = 0; row < _boardSize; row++) {
        for (var column = 0; column < _boardSize; column++) {
          if (board[row][column] == _noValue) {
            return _trySolveCell(
              board,
              row,
              column,
              offset(),
              offset,
              maxDepth,
              progress,
            );
          }
        }
      }
      return true;
    }

    final nextCell = _fewestCandidateCell(board);
    if (nextCell != null) {
      return _trySolveCell(
        board,
        nextCell.$1,
        nextCell.$2,
        offset(),
        offset,
        maxDepth,
        progress,
      );
    }
    return true;
  }

  (int, int)? _fewestCandidateCell(Board board) {
    var selectedRow = -1;
    var selectedColumn = -1;
    var fewestCandidates = _boardSize + 1;
    for (var row = 0; row < _boardSize; row++) {
      for (var column = 0; column < _boardSize; column++) {
        if (board[row][column] != _noValue) continue;

        var candidateCount = 0;
        for (var value = 1; value <= _boardSize; value++) {
          if (isValidCell(board, row, column, value)) candidateCount++;
        }
        if (candidateCount < fewestCandidates) {
          fewestCandidates = candidateCount;
          selectedRow = row;
          selectedColumn = column;
          if (candidateCount == 0) return (row, column);
        }
      }
    }
    return selectedRow == -1 ? null : (selectedRow, selectedColumn);
  }

  bool _trySolveCell(
    Board board,
    int row,
    int column,
    int offsetValue,
    int Function() offset,
    int maxDepth,
    _SolverProgress progress,
  ) {
    for (int candidate = 0; candidate < _boardSize; candidate++) {
      final value = (offsetValue + candidate) % _boardSize + 1;
      if (!isValidCell(board, row, column, value)) continue;

      board[row][column] = value;
      progress.visitedCandidates++;
      final profile = progress.profile;
      if (profile != null) profile.candidateAssignments++;
      if (_solveBoard(board, offset, maxDepth, progress)) return true;
      board[row][column] = _noValue;
    }
    return false;
  }

  Future<bool> isUniqueCell(
    Board board,
    int row,
    int column, {
    int Function() offset = _returnZero,
    int maxDepth = 10000,
  }) async =>
      _isUniqueCell(board, row, column, offset: offset, maxDepth: maxDepth);

  bool _isUniqueCell(
    Board board,
    int row,
    int column, {
    required int Function() offset,
    required int maxDepth,
  }) {
    final originalValue = board[row][column];
    final candidateBoard = _uniquenessBoard;
    _copyBoardInto(board, candidateBoard);
    final progress = _uniquenessProgress;

    for (int value = 1; value <= _boardSize; value++) {
      if (value == originalValue ||
          !isValidCell(candidateBoard, row, column, value)) {
        continue;
      }

      candidateBoard[row][column] = value;
      progress.visitedCandidates = 0;
      if (_solveBoard(
        candidateBoard,
        offset,
        maxDepth,
        progress,
      )) {
        return false;
      }
      candidateBoard[row][column] = originalValue;
    }
    return true;
  }
}

class _SolverProgress {
  _SolverProgress({this.profile});

  final SudokuGenerationProfile? profile;
  int visitedCandidates = 0;
}

class SudokuGenerationProfile {
  final Stopwatch _generationWatch = Stopwatch();
  final Stopwatch _stageWatch = Stopwatch();

  int generationMicroseconds = 0;
  int uniquenessChecks = 0;
  int uniquenessMicroseconds = 0;
  int searchNodes = 0;
  int candidateAssignments = 0;

  void startGeneration() => _generationWatch
    ..reset()
    ..start();

  void finishGeneration() {
    _generationWatch.stop();
    generationMicroseconds += _generationWatch.elapsedMicroseconds;
    _generationWatch.reset();
  }

  void startUniquenessCheck() {
    uniquenessChecks++;
    _stageWatch
      ..reset()
      ..start();
  }

  void finishUniquenessCheck() {
    _stageWatch.stop();
    uniquenessMicroseconds += _stageWatch.elapsedMicroseconds;
  }
}

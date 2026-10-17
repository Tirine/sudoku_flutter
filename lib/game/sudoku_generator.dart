import 'dart:isolate';
import 'dart:math';

import 'package:sudoku_flutter/game/sudoku_logic_solver.dart';
import 'package:sudoku_flutter/utils.dart';

typedef Board = List<List<int>>;

enum SudokuDifficulty { easy, medium, hard, extreme }

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

  static int _returnZero() => 0;

  static Future<SudokuGenerator> create(
      {int? seed, difficulty = SudokuDifficulty.easy}) async {
    var obj = await Isolate.run(() async {
      SudokuGenerator created = SudokuGenerator(
          seed: seed ?? -1, difficulty: difficulty, initialise: false);
      await created.init();
      return {
        'seed': created.seed,
        'initialised': created._initialised,
        'solution': created.solution,
        'sudoku': created._sudoku
      };
    });
    var returnVal = SudokuGenerator._(
        obj['seed'] as int,
        difficulty,
        obj['initialised'] as bool,
        obj['solution'] as Board,
        obj['sudoku'] as Board);
    printSudoku(returnVal._solution);
    return returnVal;
  }

  static Board createEmpty() => Board.generate(
      9, (index) => List<int>.generate(9, (index) => 0, growable: false),
      growable: false);

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
    Board board = createEmpty();
    for (var i = 0; i < obj.length; i++) {
      board[i] = List<int>.from(obj[i]);
    }
    return board;
  }

  SudokuGenerator(
      {int seed = -1,
      SudokuDifficulty difficulty = SudokuDifficulty.easy,
      initialise = true})
      : _difficulty = difficulty,
        _seed = seed {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }

    _random = mulberry32(_offsetSeed());
    if (initialise) {
      init();
    }
  }
  SudokuGenerator._(this._seed, this._difficulty, this._initialised,
      this._solution, this._sudoku) {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }
    _random = mulberry32(_offsetSeed());
  }

  int Function() mulberry32(a) {
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
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }
    _random = mulberry32(_offsetSeed());
    _initialised = true;

    var sudoku = _createSeedBoard();
    final seedBoard = cloneBoard(sudoku);
    while (!(await solver(sudoku, offset: _rand))) {
      sudoku = cloneBoard(seedBoard);
    }
    final solution = cloneBoard(sudoku);
    _sudoku = await _removeClues(
      sudoku,
      solution,
      minFilled: _minimumClueCount(),
    );
    _solution = solution;
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
      default:
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
          requireLogicalSolve: _difficulty == SudokuDifficulty.extreme,
        );
        if (generated) return sudoku;
      } catch (e) {
        maxDepth *= 2;
        printDebug('Retry...');
        sudoku = cloneBoard(solution);
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

  bool verifyCell(row, column) {
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
    bool requireLogicalSolve = false,
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
    final logicalSolver = requireLogicalSolve ? SudokuLogicSolver() : null;

    for (int i = 0; i <= _boardSize; i++) {
      for (int j = 0; j <= _boardSize; j++) {
        if (_tryRemoveClue(
          board,
          rowI,
          colI,
          logicalSolver: logicalSolver,
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
    required SudokuLogicSolver? logicalSolver,
    required int maxDepth,
  }) {
    if (board[row][column] == _noValue ||
        !_isUniqueCell(
          board,
          row,
          column,
          offset: _rand,
          maxDepth: maxDepth,
        )) {
      return false;
    }

    final clue = board[row][column];
    board[row][column] = _noValue;
    if (logicalSolver != null && !logicalSolver.canSolve(board)) {
      board[row][column] = clue;
      return false;
    }
    return true;
  }

  Future<bool> solver(
    Board data, {
    int Function() offset = _returnZero,
    int maxDepth = 0,
  }) async {
    return _solveBoard(data, offset, maxDepth, _SolverProgress());
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

    for (int row = 0; row < _boardSize; row++) {
      for (int column = 0; column < _boardSize; column++) {
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
    final candidateBoard = cloneBoard(board);

    for (int value = 1; value <= _boardSize; value++) {
      if (value == originalValue ||
          !isValidCell(candidateBoard, row, column, value)) {
        continue;
      }

      candidateBoard[row][column] = value;
      if (_solveBoard(
        candidateBoard,
        offset,
        maxDepth,
        _SolverProgress(),
      )) {
        return false;
      }
      candidateBoard[row][column] = originalValue;
    }
    return true;
  }
}

class _SolverProgress {
  int visitedCandidates = 0;
}

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sudoku_flutter/sudoku_logic_solver.dart';

typedef Board = List<List<int>>;

enum SudokuDifficulty { easy, medium, hard, extreme }

class Sudoku {
  final SudokuDifficulty _difficulty;
  bool _initialised = false;
  int _seed;
  late int Function() _random;
  Board _sudoku = createEmpty();
  Board _solution = createEmpty();
  int _sleep = 0;
  Sudoku(
      {int seed = -1,
      SudokuDifficulty difficulty = SudokuDifficulty.easy,
      initialise = true,
      sleep = 0})
      : _difficulty = difficulty,
        _seed = seed,
        _sleep = sleep {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }

    _random = mulberry32(_offsetSeed());
    if (initialise) {
      init();
    }
  }
  Sudoku._(this._seed, this._difficulty, this._initialised, this._solution,
      this._sudoku) {
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

  static Future<Sudoku> create(
      {seed = -1, difficulty = SudokuDifficulty.easy, sleep = 0}) async {
    var obj = await Isolate.run(() async {
      Sudoku created = Sudoku(
          seed: seed, difficulty: difficulty, initialise: false, sleep: sleep);
      await created.init();
      return {
        'seed': created.seed,
        'initialised': created._initialised,
        'solution': created.solution,
        'sudoku': created._sudoku
      };
    });
    var returnVal = Sudoku._(
        obj['seed'] as int,
        difficulty,
        obj['initialised'] as bool,
        obj['solution'] as Board,
        obj['sudoku'] as Board);
    printSudoku(returnVal._solution);
    return returnVal;
  }

  Future<void> init() async {
    if (_seed < 0) {
      _seed = Random.secure().nextInt(_randMax);
    }
    _random = mulberry32(_offsetSeed());
    _initialised = true;
    Board sudoku = createEmpty();
    if (_seed < 100) {
      int choose = _rand() - 1;
      int direction = (_rand() % 2) == 0 ? -1 : 1;
      if (_seed < 25) {
        for (int i = 1; i <= sudoku[choose].length; i++) {
          sudoku[choose][i - 1] = (10 + (i * direction)) % 10;
        }
      } else if (_seed < 50) {
        for (int i = 1; i <= sudoku[choose].length; i++) {
          sudoku[i - 1][choose] = (10 + (i * direction)) % 10;
        }
      } else if (_seed < 75) {
        for (int i = 1; i <= sudoku[choose].length; i++) {
          sudoku[((choose % 3) * 3) + ((i - 1) / 3).floor()]
                  [((choose / 3).floor() * 3) + (i - 1) % 3] =
              (10 + (i * direction)) % 10;
        }
      } else {
        int upDown = (_rand() % 2) == 0 ? -1 : 1;
        for (int i = 1; i <= sudoku[choose].length; i++) {
          sudoku[((upDown * i - 1 + choose)) % 9][(((i) - 1)) % 9] =
              (10 + (i * direction)) % 10;
        }
      }
    }
    if (_seed == 314159265) {
      const piList = [3, 1, 4, 1, 5, 9, 2, 6, 5];
      for (int i = 0; i < piList.length; i++) {
        sudoku[i][i] = piList[i];
      }
    }
    if (_seed == 271828182) {
      const eList = [2, 7, 1, 8, 2, 8, 1, 8, 2];
      for (int i = 0; i < eList.length; i++) {
        sudoku[i][i] = eList[i];
      }
    }
    if (_seed == 123456789) {
      const counter = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      for (int i = 0; i < counter.length; i++) {
        sudoku[i][i] = counter[i];
      }
    }

    Board solution = cloneBoard(sudoku);
    while (!(await solver(sudoku, offset: _rand))) {
      sudoku = cloneBoard(solution);
    }
    solution = cloneBoard(sudoku);
    bool generated = false;
    int maxDepth = 5000;
    int minFill = 17;
    if (_difficulty != SudokuDifficulty.extreme) {
      minFill += 16;
      if (_difficulty == SudokuDifficulty.easy) {
        minFill += 16;
      } else if (_difficulty == SudokuDifficulty.medium) {
        minFill += 8;
      }
    }
    while (!generated) {
      try {
        generated = await _generateBoard(sudoku,
            maxDepth: maxDepth,
            minFilled: minFill,
            requireLogicalSolve: _difficulty == SudokuDifficulty.extreme);
      } catch (e) {
        maxDepth *= 2;
        _debugPrint('Retry...');
        sudoku = cloneBoard(solution);
      }
    }
    _solution = solution;
    _sudoku = sudoku;
    // printSudoku(_solution);
    // printSudoku(_sudoku);
    // _debugPrint(_sudoku.fold(
    //     '',
    //     (previousValue, element) =>
    //         previousValue +
    //         element.fold(
    //             '',
    //             (previousValue, element) =>
    //                 '$previousValue${element == 0 ? '.' : element}')));
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

  Future<bool> _generateBoard(Board board,
      {minFilled = 0, maxDepth = 2e4, requireLogicalSolve = false}) async {
    int rowI = _rand() - 1;
    int colI = _rand() - 1;
    void next() {
      rowI += 1;
      if (rowI == 9) {
        rowI %= 9;
        colI += 1;
        colI %= 9;
      }
      sleep(Duration(milliseconds: _sleep));
    }

    // int tries = 0;
    int filled = 81;
    final logicalSolver = requireLogicalSolve ? SudokuLogicSolver() : null;
    uniqueCellFunc() =>
        isUniqueCell(board, rowI, colI, offset: _rand, maxDepth: maxDepth);

    for (int i = 0; i <= 9; i++) {
      for (int j = 0; j <= 9; j++) {
        // tries++;
        // debugPrint('tries', (i), (j))
        if (board[rowI][colI] != _noValue && await uniqueCellFunc()) {
          final clue = board[rowI][colI];
          board[rowI][colI] = _noValue;
          if (logicalSolver != null && !logicalSolver.canSolve(board)) {
            board[rowI][colI] = clue;
            next();
          } else {
            filled--;
            // printSudoku(board)
            rowI = _rand() - 1;
            colI = _rand() - 1;
            i = 0;
            j = 0;
          }
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

  static const _noValue = 0;
  static const _randMax = 1 << 32;
  static int _returnZero() => 0;
  static void _debugPrint(String string) {
    if (kDebugMode) {
      print(string);
    }
  }

  static Board createEmpty() => Board.generate(
      9, (index) => List<int>.generate(9, (index) => 0, growable: false),
      growable: false);

  static void _printLine() {
    _debugPrint('-+ -+ -+ -+ -+ -+ -+ -+ -+ ');
  }

  static void printSudoku(Board board) {
    for (int row = 0; row < board.length; row++) {
      String string = '';
      if (row % 3 == 0) {
        _printLine();
      }
      for (int column = 0; column < board[row].length; column++) {
        if (column % 3 == 0) {
          string += ': ';
        }
        if (board[row][column] != 0) {
          string += '${board[row][column]} ';
        } else {
          string += ' . ';
        }
      }
      _debugPrint('$string:');
    }
    _printLine();
  }

  static bool isValidCell(board, row, col, value) {
    for (int i = 0; i < 9; i++) {
      final m = 3 * (row / 3).floor() + (i / 3).floor();
      final n = 3 * (col / 3).floor() + i % 3;
      if (board[row][i] == value ||
          board[i][col] == value ||
          board[m][n] == value) {
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

  Future<bool> solver(Board data, {offset = _returnZero, maxDepth = 0}) async {
    int depth = 0;
    bool sudokuSolverImpl(Board data) {
      if (maxDepth > 1000 && depth > maxDepth) {
        throw 'Went too deep';
      }
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (data[i][j] == _noValue) {
            final offsetVal = offset();
            for (int value = 0; value < 9; value++) {
              final val = (offsetVal + value) % 9 + 1;
              if (isValidCell(data, i, j, val)) {
                data[i][j] = val;
                depth++;
                if (sudokuSolverImpl(data)) {
                  return true;
                } else {
                  data[i][j] = _noValue;
                }
              }
            }
            return false;
          }
        }
      }
      sleep(Duration(microseconds: _sleep));
      return true;
    }

    try {
      return sudokuSolverImpl(data);
    } finally {
      // debugPrint('$depth');
    }
  }

  Future<bool> isUniqueCell(Board board, row, col,
      {offset = _returnZero, maxDepth = 1e4}) async {
    final val = board[row][col];
    for (int value = 1; value < 10; value++) {
      if (val == value) {
        continue;
      }
      Board cloned = cloneBoard(board);
      if (isValidCell(cloned, row, col, value)) {
        cloned[row][col] = value;
        if (await solver(cloned, offset: offset, maxDepth: maxDepth)) {
          return false;
        }
      }
    }
    return true;
  }
}

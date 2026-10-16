import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_flutter/last_game_store.dart';
import 'package:sudoku_flutter/main.dart';
import 'package:sudoku_flutter/scoreboard.dart';
import 'package:sudoku_flutter/sudoku.dart';
import 'package:sudoku_flutter/sudoku_game_controller.dart';
import 'package:sudoku_flutter/sudoku_puzzle_pool.dart';

void main() {
  testWidgets('blocks new puzzle requests while a puzzle is loading',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final puzzleCompleter = Completer<Sudoku>();
    var createCalls = 0;
    final pool = SudokuPuzzlePool(
      preloadCount: 0,
      create: (difficulty) {
        createCalls++;
        return puzzleCompleter.future;
      },
    );

    await tester.pumpWidget(MyApp(puzzlePool: pool));
    await tester.pump();

    expect(createCalls, 1);

    final newPuzzleButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('new-puzzle')),
    );
    final difficultyMenu = tester.widget<DropdownButton<SudokuDifficulty>>(
      find.byKey(const ValueKey('difficulty')),
    );
    final seedField = tester.widget<TextField>(
      find.byKey(const ValueKey('seed-input')),
    );

    expect(newPuzzleButton.onPressed, isNull);
    expect(difficultyMenu.onChanged, isNull);
    expect(seedField.enabled, isFalse);

    // Attempting to interact with the disabled controls must not start an
    // additional puzzle load.
    await tester.tap(
      find.byKey(const ValueKey('new-puzzle')),
      warnIfMissed: false,
    );
    await tester.tap(
      find.byKey(const ValueKey('difficulty')),
      warnIfMissed: false,
    );
    await tester.tap(
      find.byKey(const ValueKey('seed-input')),
      warnIfMissed: false,
    );
    expect(createCalls, 1);

    puzzleCompleter.complete(
      Sudoku(seed: 1, difficulty: SudokuDifficulty.easy, initialise: false),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('new-puzzle')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<DropdownButton<SudokuDifficulty>>(
            find.byKey(const ValueKey('difficulty')),
          )
          .onChanged,
      isNotNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('seed-input')))
          .enabled,
      isTrue,
    );
  });

  testWidgets('offers saved game choices only at startup',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStore().save({
      'seed': 12,
      'difficulty': 'easy',
      'board': List.generate(9, (_) => List<int>.filled(9, 0)),
      'notes': List.generate(
        9,
        (_) => List.generate(9, (_) => <int>[]),
      ),
      'elapsedSeconds': 15,
      'undoHistory': <Object>[],
    });
    final pool = SudokuPuzzlePool(
      preloadCount: 0,
      create: (difficulty) async => Sudoku(
        seed: 13,
        difficulty: difficulty,
        initialise: false,
      ),
    );

    await tester.pumpWidget(MyApp(puzzlePool: pool));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-last-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-new-game')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-new-game')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome back'), findsNothing);
    expect(find.byKey(const ValueKey('resume-last-game')), findsNothing);
    expect(find.byKey(const ValueKey('new-puzzle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkpoints elapsed time while playing',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MyApp(puzzlePool: _createTestPool()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    final progress = await LastGameStore().load();
    expect(progress?['elapsedSeconds'], greaterThanOrEqualTo(5));
  });

  testWidgets('starts directly into a puzzle when no saved game exists',
      (tester) async {
    await _pumpGame(tester);

    expect(find.text('Welcome back'), findsNothing);
    expect(find.byKey(const ValueKey('sudoku-board')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a recoverable message when puzzle loading fails',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pool = SudokuPuzzlePool(
      preloadCount: 0,
      create: (difficulty) => Future.error(StateError('generation failed')),
    );

    await tester.pumpWidget(MyApp(puzzlePool: pool));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Could not create a puzzle'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('new-puzzle')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when stored scoreboard data cannot be loaded',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'sudoku_best_times_easy': '{invalid json',
    });
    await _pumpGame(tester, resetPreferences: false);

    await tester.tap(find.byKey(const ValueKey('scoreboard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.textContaining('Could not load the scoreboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discards malformed saved progress and starts a new puzzle',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'sudoku_last_game_v1': '{malformed json',
    });

    await _pumpGame(tester, resetPreferences: false);

    expect(find.text('Welcome back'), findsNothing);
    expect(await LastGameStore().load(), containsPair('seed', 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears invalid saved difficulty when resuming', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStore().save({
      'seed': 12,
      'difficulty': 'unknown',
      'board': List.generate(9, (_) => List<int>.filled(9, 0)),
      'notes': List.generate(9, (_) => List.generate(9, (_) => <int>[])),
      'elapsedSeconds': 15,
      'undoHistory': <Object>[],
    });
    await _pumpGame(
      tester,
      resetPreferences: false,
      awaitingResumeChoice: true,
    );

    await tester.tap(find.byKey(const ValueKey('continue-last-game')));
    await tester.pump();
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Could not resume your game'), findsOneWidget);
    expect(await LastGameStore().load(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders and responds to the Sudoku play controls',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(puzzlePool: _createTestPool()));

    expect(find.text('SUDOKU'), findsOneWidget);
    expect(find.byKey(const ValueKey('sudoku-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('sudoku-grid-lines')), findsOneWidget);
    expect(find.byKey(const ValueKey('scoreboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-puzzle')), findsOneWidget);
    expect(find.byKey(const ValueKey('difficulty')), findsOneWidget);
    final difficultyMenu = tester.widget<DropdownButton<SudokuDifficulty>>(
      find.byKey(const ValueKey('difficulty')),
    );
    expect(
      difficultyMenu.items!.map((item) => (item.child as Text).data),
      contains('Extreme'),
    );
    expect(find.byKey(const ValueKey('seed-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('erase')), findsOneWidget);

    for (var attempt = 0; attempt < 80; attempt++) {
      final newPuzzleButton =
          tester.widget<FilledButton>(find.byKey(const ValueKey('new-puzzle')));
      if (newPuzzleButton.onPressed != null) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }

    final newPuzzleButton =
        tester.widget<FilledButton>(find.byKey(const ValueKey('new-puzzle')));
    expect(newPuzzleButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('notes-toggle')));
    await tester.pump();
    expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('notes-toggle')))
            .selected,
        isTrue);

    final emptyCell = find
        .bySemanticsLabel(
          RegExp(r'Row \d+, column \d+, empty'),
        )
        .first;
    final emptyCellCenter = tester.getCenter(emptyCell);
    await tester.tap(emptyCell);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('digit-5')));
    await tester.pump();
    expect(find.text('5'), findsAtLeastNWidgets(2));
    final singleNote = find.bySemanticsLabel(RegExp('notes'));
    expect(singleNote, findsOneWidget);
    final boardRect =
        tester.getRect(find.byKey(const ValueKey('sudoku-board')));
    final noteElement = find.text('5').evaluate().firstWhere((element) {
      final center = tester.getCenter(
        find.byElementPredicate((candidate) => identical(candidate, element)),
      );
      return boardRect.contains(center);
    });
    final noteCenter = tester.getCenter(
      find.byElementPredicate((candidate) => identical(candidate, noteElement)),
    );
    expect((noteCenter.dx - emptyCellCenter.dx).abs(), lessThan(1));
    expect((noteCenter.dy - emptyCellCenter.dy).abs(), lessThan(1));

    await tester.tap(find.byKey(const ValueKey('notes-toggle')));
    await tester.pump();
    expect(singleNote, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('digit-5')));
    await tester.pump();
    expect(singleNote, findsNothing);
    expect(find.text('5'), findsAtLeastNWidgets(2));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(find.byKey(const ValueKey('sudoku-board')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows saved times grouped by difficulty', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sudoku_best_times_easy': '[31,52]',
      'sudoku_best_times_hard': '[84]',
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(puzzlePool: _createTestPool()));
    await tester.tap(find.byKey(const ValueKey('scoreboard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Best times'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('Easy')),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Hard')),
        findsOneWidget);
    expect(find.text('00:31'), findsOneWidget);
    expect(find.text('00:52'), findsOneWidget);
    expect(find.text('01:24'), findsOneWidget);
    expect(find.text('No times yet'), findsNWidgets(2));
  });

  testWidgets('changing difficulty uses a preloaded puzzle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final created = <SudokuDifficulty, List<Sudoku>>{
      for (final difficulty in SudokuDifficulty.values) difficulty: [],
    };
    var seed = 1;
    final pool = SudokuPuzzlePool(
      create: (difficulty) async {
        final puzzle = Sudoku(
          seed: seed++,
          difficulty: difficulty,
          initialise: false,
        );
        created[difficulty]!.add(puzzle);
        return puzzle;
      },
    );

    await tester.pumpWidget(MyApp(puzzlePool: pool));
    await tester.pump();
    await tester.pump();

    expect(created[SudokuDifficulty.medium], hasLength(3));
    final firstPreloadedMedium = created[SudokuDifficulty.medium]!.first;

    await tester.tap(find.byKey(const ValueKey('difficulty')));
    await tester.pump();
    await tester.tap(find.text('Medium').last);
    await tester.pump();
    await tester.pump();

    final seedField = tester.widget<TextField>(
      find.byKey(const ValueKey('seed-input')),
    );
    expect(seedField.controller!.text, '${firstPreloadedMedium.seed}');
    expect(pool.bufferedCount(SudokuDifficulty.medium), 3);
  });

  testWidgets('resumes saved board, notes, undo history, and elapsed time',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = (await tester.runAsync<Sudoku>(
      () => Sudoku.create(
        seed: 123456,
        difficulty: SudokuDifficulty.easy,
      ),
    ))!;
    final controller = SudokuGameController(
      initialGame: game,
      startTimer: false,
    );
    final editableCell = _firstEditableCell(game);
    controller
      ..toggleNotes(true)
      ..selectCell(editableCell.$1, editableCell.$2)
      ..selectNumber(8);
    controller.elapsedSeconds = 37;
    await LastGameStore().save(controller.exportProgress());
    controller.dispose();

    await _pumpGame(
      tester,
      resetPreferences: false,
      awaitingResumeChoice: true,
    );
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-last-game')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('00:37'), findsOneWidget);
    expect(
      _cellLabelMatching(RegExp('notes')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('undo')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pump();
    expect(
      _cellLabel(
        'Row ${editableCell.$1 + 1}, column ${editableCell.$2 + 1}, empty',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses the timer in background and saves the final elapsed time',
      (tester) async {
    await _pumpGame(tester);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:02'), findsOneWidget);
    expect((await LastGameStore().load())?['elapsedSeconds'], 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:04'), findsOneWidget);
  });

  testWidgets('rejects an empty seed without replacing the current puzzle',
      (tester) async {
    await _pumpGame(tester);
    final seedField = find.byKey(const ValueKey('seed-input'));
    final givenCell = _cellLabel('Row 1, column 3, 3');
    expect(givenCell, findsOneWidget);

    await tester.enterText(seedField, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter a seed of 0 or higher.'), findsOneWidget);
    expect(givenCell, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads the submitted seed and displays it for replay',
      (tester) async {
    await _pumpGame(tester);
    final seedField = find.byKey(const ValueKey('seed-input'));

    await tester.enterText(seedField, '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(seedField).controller!.text,
      '123456',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('erases entries and notes and allows undo from the controls',
      (tester) async {
    await _pumpGame(tester);
    final cell = find.bySemanticsLabel('Row 1, column 1, empty');

    await tester.tap(cell);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('digit-5')));
    await tester.pump();
    expect(_cellLabel('Row 1, column 1, 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pump();
    expect(_cellLabel('Row 1, column 1, empty'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('digit-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('erase')));
    await tester.pump();
    expect(_cellLabel('Row 1, column 1, empty'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notes-toggle')));
    await tester.tap(find.byKey(const ValueKey('digit-6')));
    await tester.pump();
    expect(
      _cellLabelMatching(RegExp('Row 1, column 1.*notes')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('erase')));
    await tester.pump();
    expect(_cellLabel('Row 1, column 1, empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows incorrect completion feedback once for the same board',
      (tester) async {
    await _pumpGame(tester, game: _nearlySolvedGame());

    await tester.tap(find.bySemanticsLabel('Row 1, column 1, empty'));
    await tester.tap(find.byKey(const ValueKey('digit-9')));
    await tester.tap(find.bySemanticsLabel('Row 1, column 2, empty'));
    await tester.tap(find.byKey(const ValueKey('digit-8')));
    await tester.pump();
    expect(
      find.text('Not quite right yet. Check your entries and try again.'),
      findsOneWidget,
    );

    // Selecting the same value rechecks the unchanged full board. It should
    // not enqueue another copy of the same warning.
    await tester.tap(find.byKey(const ValueKey('digit-8')));
    await tester.pump();
    expect(
      find.text('Not quite right yet. Check your entries and try again.'),
      findsOneWidget,
    );
    expect(find.text('Puzzle complete'), findsNothing);
  });

  testWidgets('completing a puzzle records the time and disables game edits',
      (tester) async {
    await _pumpGame(tester, game: _nearlySolvedGame());

    await tester.tap(find.bySemanticsLabel('Row 1, column 1, empty'));
    await tester.tap(find.byKey(const ValueKey('digit-1')));
    await tester.tap(find.bySemanticsLabel('Row 1, column 2, empty'));
    await tester.tap(find.byKey(const ValueKey('digit-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Puzzle complete'), findsOneWidget);
    expect(find.textContaining('That is #1 on the Easy scoreboard!'),
        findsOneWidget);
    expect((await ScoreboardStore().loadScores())[SudokuDifficulty.easy], [0]);
    expect(await LastGameStore().load(), isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('undo')))
          .onPressed,
      isNull,
    );
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('erase')))
            .onPressed,
        isNull);
  });

  testWidgets('fits the board and controls on a small phone viewport',
      (tester) async {
    await _pumpGame(tester, viewSize: const Size(320, 568));

    expect(find.byKey(const ValueKey('sudoku-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('erase')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SudokuPuzzlePool _createTestPool() => SudokuPuzzlePool(
      create: (difficulty) async => Sudoku(
        seed: 1,
        difficulty: difficulty,
        initialise: false,
      ),
    );

Future<void> _pumpGame(
  WidgetTester tester, {
  Sudoku? game,
  bool resetPreferences = true,
  bool awaitingResumeChoice = false,
  Size viewSize = const Size(390, 844),
}) async {
  if (resetPreferences) SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final testGame = game ?? _nearlySolvedGame();
  final pool = SudokuPuzzlePool(
    preloadCount: 0,
    create: (difficulty) async => testGame,
  );
  await tester.pumpWidget(MyApp(puzzlePool: pool));
  if (awaitingResumeChoice) {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Welcome back'), findsOneWidget);
    return;
  }
  for (var attempt = 0; attempt < 40; attempt++) {
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('new-puzzle')),
    );
    final seed = tester
        .widget<TextField>(
          find.byKey(const ValueKey('seed-input')),
        )
        .controller!
        .text;
    if (button.onPressed != null && seed.isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('seed-input')))
        .controller!
        .text,
    isNotEmpty,
    reason: 'The test puzzle should finish loading before interactions.',
  );
}

Sudoku _nearlySolvedGame() {
  const solution = [
    [1, 2, 3, 4, 5, 6, 7, 8, 9],
    [4, 5, 6, 7, 8, 9, 1, 2, 3],
    [7, 8, 9, 1, 2, 3, 4, 5, 6],
    [2, 3, 4, 5, 6, 7, 8, 9, 1],
    [5, 6, 7, 8, 9, 1, 2, 3, 4],
    [8, 9, 1, 2, 3, 4, 5, 6, 7],
    [3, 4, 5, 6, 7, 8, 9, 1, 2],
    [6, 7, 8, 9, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
  final game = Sudoku(seed: 7, initialise: false);
  for (var row = 0; row < 9; row++) {
    game.solution[row].setAll(0, solution[row]);
    game.board[row].setAll(0, solution[row]);
  }
  game.board[0][0] = 0;
  game.board[0][1] = 0;
  return game;
}

Finder _cellLabel(String label) =>
    _cellLabelMatching(RegExp('^${RegExp.escape(label)}\$'));

Finder _cellLabelMatching(RegExp pattern) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          pattern.hasMatch(widget.properties.label ?? ''),
    );

(int, int) _firstEditableCell(Sudoku game) {
  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 9; column++) {
      if (game.board[row][column] == 0) return (row, column);
    }
  }
  throw StateError('Test puzzle has no editable cells.');
}

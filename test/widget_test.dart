import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_flutter/main.dart';
import 'package:sudoku_flutter/sudoku.dart';
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
}

SudokuPuzzlePool _createTestPool() => SudokuPuzzlePool(
      create: (difficulty) async => Sudoku(
        seed: 1,
        difficulty: difficulty,
        initialise: false,
      ),
    );

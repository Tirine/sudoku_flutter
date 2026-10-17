import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/game/sudoku_puzzle_pool.dart';

void main() {
  test('preloads only the requested difficulty and replenishes after take',
      () async {
    final created = <SudokuDifficulty, List<SudokuGenerator>>{
      for (final difficulty in SudokuDifficulty.values) difficulty: [],
    };
    var seed = 0;
    final pool = SudokuPuzzlePool(
      create: (difficulty, s) async {
        final puzzle = SudokuGenerator(
          seed: seed++,
          difficulty: difficulty,
          initialise: false,
        );
        created[difficulty]!.add(puzzle);
        return puzzle;
      },
    );

    pool.preload(SudokuDifficulty.medium);
    await Future<void>.delayed(Duration.zero);

    expect(pool.bufferedCount(SudokuDifficulty.medium), 3);
    expect(created[SudokuDifficulty.medium], hasLength(3));
    expect(
      created.values.fold<int>(0, (total, boards) => total + boards.length),
      3,
    );

    final firstMediumPuzzle = created[SudokuDifficulty.medium]!.first;
    final selected = await pool.take(SudokuDifficulty.medium);

    expect(identical(selected, firstMediumPuzzle), isTrue);
    expect(pool.bufferedCount(SudokuDifficulty.medium), 3);
    expect(created[SudokuDifficulty.medium], hasLength(4));
  });

  test('preloads all the difficulties and replenishes after take', () async {
    final created = <SudokuDifficulty, List<SudokuGenerator>>{
      for (final difficulty in SudokuDifficulty.values) difficulty: [],
    };
    var seed = 0;
    final pool = SudokuPuzzlePool(
      create: (difficulty, s) async {
        final puzzle = SudokuGenerator(
          seed: seed++,
          difficulty: difficulty,
          initialise: false,
        );
        created[difficulty]!.add(puzzle);
        return puzzle;
      },
    );

    pool.preloadAll();
    await Future<void>.delayed(Duration.zero);

    for (var difficulty in SudokuDifficulty.values) {
      expect(pool.bufferedCount(difficulty), 3);
      expect(created[difficulty], hasLength(3));
    }
    expect(
      created.values.fold<int>(0, (total, boards) => total + boards.length),
      // Preloaded=3
      SudokuDifficulty.values.length * 3,
    );

    for (var difficulty in SudokuDifficulty.values) {
      final firstMediumPuzzle = created[difficulty]!.first;
      final selected = await pool.take(difficulty);

      expect(identical(selected, firstMediumPuzzle), isTrue);
      expect(pool.bufferedCount(difficulty), 3);
      expect(created[difficulty], hasLength(4));
    }
    expect(
      created.values.fold<int>(0, (total, boards) => total + boards.length),
      // Preloaded=3 + each new
      SudokuDifficulty.values.length * 4,
    );
  });

  test('limits concurrent generation across all difficulties', () async {
    final releases = <Completer<SudokuGenerator>>[];
    var active = 0;
    var maxActive = 0;
    final pool = SudokuPuzzlePool(
      preloadCount: 3,
      maxConcurrentGenerations: 2,
      create: (difficulty, s) {
        active++;
        if (active > maxActive) maxActive = active;
        final release = Completer<SudokuGenerator>();
        releases.add(release);
        return release.future.whenComplete(() => active--);
      },
    );

    pool.preload(SudokuDifficulty.easy);
    pool.preload(SudokuDifficulty.extreme);
    await Future<void>.delayed(Duration.zero);

    expect(active, 2);
    expect(maxActive, 2);
    expect(releases, hasLength(2));

    for (var index = 0; index < 6; index++) {
      while (releases.length <= index) {
        await Future<void>.delayed(Duration.zero);
      }
      final release = releases[index];
      expect(release.isCompleted, isFalse);
      release.complete(SudokuGenerator(
          difficulty: SudokuDifficulty.easy, initialise: false));
      await Future<void>.delayed(Duration.zero);
    }

    expect(active, 0);
    expect(maxActive, 2);
  });
}

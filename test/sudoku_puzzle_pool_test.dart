import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/sudoku.dart';
import 'package:sudoku_flutter/sudoku_puzzle_pool.dart';

void main() {
  test('preloads three puzzles per difficulty and replenishes consumed boards',
      () async {
    final created = <SudokuDifficulty, List<Sudoku>>{
      for (final difficulty in SudokuDifficulty.values) difficulty: [],
    };
    var seed = 0;
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

    pool.preloadAll();
    await Future<void>.delayed(Duration.zero);

    for (final difficulty in SudokuDifficulty.values) {
      expect(pool.bufferedCount(difficulty), 3);
      expect(created[difficulty], hasLength(3));
    }

    final firstMediumPuzzle = created[SudokuDifficulty.medium]!.first;
    final selected = await pool.take(SudokuDifficulty.medium);

    expect(identical(selected, firstMediumPuzzle), isTrue);
    expect(pool.bufferedCount(SudokuDifficulty.medium), 3);
    expect(created[SudokuDifficulty.medium], hasLength(4));
  });
}

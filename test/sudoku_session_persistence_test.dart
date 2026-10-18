import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/game/sudoku_session_persistence.dart';
import 'package:sudoku_flutter/storage/last_game_store.dart';

void main() {
  test('reports when saving game progress fails', () async {
    final errors = <String>[];
    final game = _createGame();
    final session = _createSession(
      game: game,
      store: _FailingLastGameStore(),
      onError: (message, error, stackTrace) => errors.add(message),
    );

    session.gameLoaded(saveAsLastGame: false);
    await session.saveProgress();

    expect(errors, ['Could not save your game']);
  });

  test('reports when saving an elapsed-time checkpoint fails', () async {
    final errors = <String>[];
    final game = _createGame();
    final session = _createSession(
      game: game,
      store: _FailingLastGameStore(),
      onError: (message, error, stackTrace) => errors.add(message),
    );

    await session.loadProgress();
    game.elapsedSeconds = 5;
    session.onGameChanged(loading: false);
    await session.clearProgress();

    expect(errors, ['Could not save your game timer']);
  });
}

SudokuSessionPersistence _createSession({
  required SudokuGameController game,
  required LastGameStore store,
  required SessionPersistenceError onError,
}) {
  return SudokuSessionPersistence(
    game: game,
    isLoading: () => false,
    onChanged: () {},
    onError: onError,
    store: store,
  );
}

SudokuGameController _createGame() => SudokuGameController(
      initialGame: SudokuGenerator(seed: 123, initialise: false),
      startTimer: false,
    );

class _FailingLastGameStore extends LastGameStore {
  @override
  Future<Map<String, dynamic>?> load() async => {
        'seed': 123,
        'difficulty': 'easy',
        'board': SudokuGenerator.createEmpty(),
        'notes': List.generate(9, (_) => List.generate(9, (_) => <int>[])),
        'elapsedSeconds': 0,
        'undoHistory': <Object>[],
      };

  @override
  Future<void> save(Map<String, Object> progress) async {
    throw StateError('Storage unavailable');
  }

  @override
  Future<void> saveElapsedSeconds(int seconds) async {
    throw StateError('Storage unavailable');
  }

  @override
  Future<void> clear() async {}
}

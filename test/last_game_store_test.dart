import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_flutter/last_game_store.dart';

void main() {
  const savedGameKey = 'sudoku_last_game_v1';
  const elapsedKey = 'sudoku_last_game_elapsed_seconds_v1';
  final store = LastGameStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Map<String, Object> progress({int elapsedSeconds = 42}) => {
        'seed': 314159265,
        'difficulty': 'Hard',
        'board': [1, 2, 0],
        'notes': [
          [],
          [3, 4],
          []
        ],
        'elapsedSeconds': elapsedSeconds,
        'undoHistory': [
          {
            'board': [1, 0, 0],
            'notes': [[], [], []],
          },
        ],
      };

  test('load returns null when there is no saved game', () async {
    expect(await store.load(), isNull);
  });

  test('save and load preserve the saved progress', () async {
    final expected = progress();

    await store.save(expected);

    expect(await store.load(), expected);
  });

  test('elapsed checkpoint takes precedence over older saved progress',
      () async {
    await store.save(progress(elapsedSeconds: 42));
    await store.saveElapsedSeconds(47);

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!['elapsedSeconds'], 47);
    expect(loaded['seed'], 314159265);
  });

  test('clear removes saved progress and its elapsed checkpoint', () async {
    await store.save(progress());
    await store.saveElapsedSeconds(47);

    await store.clear();

    expect(await store.load(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(savedGameKey), isNull);
    expect(preferences.getInt(elapsedKey), isNull);
  });

  test('load rejects malformed JSON', () async {
    SharedPreferences.setMockInitialValues({savedGameKey: '{not json'});

    expect(store.load(), throwsFormatException);
  });

  test('load rejects saved data that does not match the required schema',
      () async {
    SharedPreferences.setMockInitialValues({
      savedGameKey: '{"seed":"wrong type"}',
    });

    expect(store.load(), throwsFormatException);
  });

  test('saveElapsedSeconds rejects negative checkpoints', () async {
    await expectLater(store.saveElapsedSeconds(-1), throwsArgumentError);
  });
}

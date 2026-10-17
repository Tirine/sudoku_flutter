import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';
import 'package:sudoku_flutter/storage/last_game_store.dart';

typedef SessionPersistenceError = void Function(
    String message, Object error, Object? stackTrace);

class SudokuSessionPersistence with WidgetsBindingObserver {
  SudokuSessionPersistence({
    required SudokuGameController game,
    required bool Function() isLoading,
    required VoidCallback onChanged,
    required SessionPersistenceError onError,
    LastGameStore? store,
  })  : _game = game,
        _isLoading = isLoading,
        _onChanged = onChanged,
        _onError = onError,
        _store = store ?? LastGameStore();

  static const _elapsedCheckpointInterval = 5;

  final SudokuGameController _game;
  final bool Function() _isLoading;
  final VoidCallback _onChanged;
  final SessionPersistenceError _onError;
  final LastGameStore _store;

  Future<void> _writes = Future<void>.value();
  bool _hasSavedGame = false;
  bool _gameTouched = false;
  int _lastElapsedCheckpoint = 0;
  bool _attached = false;

  bool get hasSavedGame => _hasSavedGame;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void dispose() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  Future<Map<String, dynamic>?> loadProgress(
      {bool rethrowInvalid = false}) async {
    Map<String, dynamic>? progress;
    try {
      progress = await _store.load();
    } catch (_) {
      await _store.clear();
      _hasSavedGame = false;
      _onChanged();
      if (rethrowInvalid) rethrow;
      return null;
    }
    _hasSavedGame = progress != null;
    _onChanged();
    return progress;
  }

  void gameLoaded({required bool saveAsLastGame}) {
    _lastElapsedCheckpoint = 0;
    _gameTouched = saveAsLastGame;
    if (saveAsLastGame) unawaited(saveProgress());
  }

  void gameResumed() {
    _lastElapsedCheckpoint = _game.elapsedSeconds;
    _gameTouched = true;
  }

  void gameCompleted() {
    _gameTouched = false;
  }

  void markTouched() {
    _gameTouched = true;
    unawaited(saveProgress());
  }

  void onGameChanged({required bool loading}) {
    final elapsed = _game.elapsedSeconds;
    if (loading ||
        _game.isComplete ||
        !_hasSavedGame ||
        elapsed - _lastElapsedCheckpoint < _elapsedCheckpointInterval) {
      return;
    }
    _lastElapsedCheckpoint = elapsed;
    _enqueueWrite(
      () => _store.saveElapsedSeconds(elapsed),
      'Could not save your game timer',
    );
  }

  Future<void> saveProgress() {
    if (_game.isComplete) return Future<void>.value();
    final progress = _game.exportProgress();
    _lastElapsedCheckpoint = _game.elapsedSeconds;
    _writes = _writes.then((_) => _store.save(progress)).then((_) {
      if (!_hasSavedGame) {
        _hasSavedGame = true;
        _onChanged();
      }
    }).catchError((Object error, Object? stackTrace) {
      _onError('Could not save your game', error, stackTrace);
    });
    return _writes;
  }

  Future<void> clearProgress() async {
    await _writes;
    await _store.clear();
    _hasSavedGame = false;
    _onChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game.resumeTimer();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _game.pauseTimer();
      if (!_isLoading() &&
          !_game.isComplete &&
          (_gameTouched || !_hasSavedGame)) {
        unawaited(saveProgress());
      }
    }
  }

  void _enqueueWrite(Future<void> Function() write, String errorMessage) {
    _writes = _writes
        .then((_) => write())
        .catchError((Object error, Object? stackTrace) {
      _onError(errorMessage, error, stackTrace);
    });
  }
}

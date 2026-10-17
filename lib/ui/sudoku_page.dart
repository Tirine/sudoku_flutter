import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:sudoku_flutter/storage/scoreboard.dart';
import 'package:sudoku_flutter/game/sudoku_generator.dart';
import 'package:sudoku_flutter/ui/widgets/sudoku_board.dart';
import 'package:sudoku_flutter/ui/widgets/sudoku_controls.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';
import 'package:sudoku_flutter/game/sudoku_puzzle_pool.dart';
import 'package:sudoku_flutter/game/sudoku_session_persistence.dart';
import 'package:sudoku_flutter/utils.dart';

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key, required this.title, this.puzzlePool});

  final String title;
  final SudokuPuzzlePool? puzzlePool;

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  final ScoreboardStore _scoreboardStore = ScoreboardStore();
  late final SudokuGameController _game = SudokuGameController(
    initialGame:
        SudokuGenerator(difficulty: SudokuDifficulty.easy, initialise: false),
    startTimer: false,
  );
  late final SudokuPuzzlePool _puzzlePool = widget.puzzlePool ??
      SudokuPuzzlePool(
        create: (SudokuDifficulty difficulty, int? seed) =>
            SudokuGenerator.create(seed: seed, difficulty: difficulty),
      );
  SudokuDifficulty selectedDifficulty = SudokuDifficulty.easy;
  final TextEditingController _seedController = TextEditingController();
  late final SudokuSessionPersistence _session = SudokuSessionPersistence(
    game: _game,
    isLoading: () => _loading,
    onChanged: _onSessionChanged,
    onError: _showPersistenceError,
  );
  bool _loading = true;
  bool _loadInProgress = false;
  String? _lastIncorrectBoard;

  @override
  void initState() {
    super.initState();
    _session.attach();
    _game.addListener(_onGameChanged);
    _puzzlePool.preloadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  Future<void> _initializeGame() async {
    final savedProgress = await _session.loadProgress();
    if (!mounted) return;
    if (savedProgress == null) {
      await _loadGame();
      return;
    }
    // Also start generating the game here.
    try {
      final progress = await _session.loadProgress(rethrowInvalid: true);

      if (progress == null) {
        const message = 'Could not resume your game';
        final error = StateError("Progress is null");
        _showPersistenceError(message, error, null);
        await _loadGame();
        return;
      }
      final seed = progress['seed'] as int;
      final difficulty = SudokuDifficulty.values.firstWhere(
        (candidate) => candidate.name == progress['difficulty'],
      );
      final gamePromise = _puzzlePool.preloadGame(difficulty, seed);
      final continueLastGame = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Welcome back'),
          content: const Text('Would you like to continue your saved game?'),
          actions: [
            TextButton(
              key: const ValueKey('start-new-game'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Start new game'),
            ),
            FilledButton(
              key: const ValueKey('continue-last-game'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue with last game'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (continueLastGame == true) {
        printDebug("Loading $seed");
        await _resumeLastGame(progress, gamePromise);
      } else {
        await _loadGame();
      }
    } catch (error, stackTrace) {
      const message = 'Error on loading previous game: ';
      _showPersistenceError(message, error, stackTrace);
      await _loadGame();
    }
  }

  @override
  void dispose() {
    _session.dispose();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _seedController.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
    _session.onGameChanged(loading: _loading);
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _showPersistenceError(
      String message, Object? error, Object? stackTrace) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$message${error == null ? '' : ": $error"}')),
    );
    printDebug(
        '$message${error == null ? ' ' : ": $error"}${stackTrace ?? ''}');
  }

  String durationToString(int duration) {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadGame({
    int? seed,
    SudokuDifficulty? difficulty,
    bool saveAsLastGame = true,
  }) async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    final nextDifficulty = difficulty ?? selectedDifficulty;
    setState(() {
      _loading = true;
    });
    if (mounted) {
      context.loaderOverlay.show();
    }

    try {
      final nextInstance = seed == null
          ? await _puzzlePool.take(nextDifficulty)
          : await SudokuGenerator.create(
              seed: seed, difficulty: nextDifficulty);
      if (!mounted) return;

      _game.load(nextInstance);
      _session.gameLoaded(saveAsLastGame: saveAsLastGame);
      setState(() {
        selectedDifficulty = nextDifficulty;
        _lastIncorrectBoard = null;
        _loading = false;
        _seedController.text = '${nextInstance.seed}';
      });
      context.loaderOverlay.hide();
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.loaderOverlay.hide();
      const message = 'Could not create a puzzle';
      _showPersistenceError(message, error, stackTrace);
    } finally {
      _loadInProgress = false;
    }
  }

  void _selectCell(int row, int column) {
    if (_loading) return;
    _game.selectCell(row, column);
    _markGameTouched();
    unawaited(_verify());
  }

  void _selectNumber(int number) {
    if (_loading) return;
    _game.selectNumber(number);
    _markGameTouched();
    unawaited(_verify());
  }

  void _toggleNotes(bool enabled) {
    _game.toggleNotes(enabled);
    _markGameTouched();
  }

  void _markGameTouched() {
    _session.markTouched();
  }

  Future<void> _resumeLastGame(Map<String, dynamic> progress,
      final Future<SudokuGenerator> gamePromise) async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    setState(() => _loading = true);
    context.loaderOverlay.show();
    try {
      final seed = progress['seed'] as int;
      final difficulty = SudokuDifficulty.values.firstWhere(
        (candidate) => candidate.name == progress['difficulty'],
      );
      final game = await gamePromise;

      if (!mounted) return;
      _game.load(game);
      _game.restoreProgress(progress);
      _session.gameResumed();
      setState(() {
        selectedDifficulty = difficulty;
        _seedController.text = '$seed';
        _lastIncorrectBoard = null;
        _loading = false;
      });
    } catch (error, stackTrace) {
      if (mounted) {
        await _session.clearProgress();
        if (!mounted) return;
        setState(() {
          _loading = false;
        });

        const message = 'Could not resume your game';
        _showPersistenceError(message, error, stackTrace);
      }
    } finally {
      if (mounted) context.loaderOverlay.hide();
      _loadInProgress = false;
    }
  }

  Future<void> _clearLastGame() async {
    await _session.clearProgress();
  }

  Future<void> _verify() async {
    if (!_game.isFilled || _game.isComplete) return;
    if (_game.verifyAndComplete()) {
      _session.gameCompleted();
      unawaited(_clearLastGame());
      final finishTime = _game.elapsedSeconds;
      final difficulty = _game.game.difficulty;
      int? scoreRank;
      try {
        scoreRank = await _scoreboardStore.recordTime(
          difficulty: difficulty,
          seconds: finishTime,
        );
      } catch (error, stackTrace) {
        const message = 'Could not save your score';
        _showPersistenceError(message, error, stackTrace);
      }
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Puzzle complete'),
          content: Text(
            scoreRank == null
                ? 'Solved in ${durationToString(finishTime)}. Nicely done.'
                : 'Solved in ${durationToString(finishTime)}. '
                    'That is #$scoreRank on the ${_capitalize(difficulty.name)} '
                    'scoreboard!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _loadGame();
              },
              child: const Text('New puzzle'),
            ),
          ],
        ),
      );
    } else {
      final boardSignature = _game.game.board.map((row) => row.join()).join();
      if (boardSignature != _lastIncorrectBoard) {
        _lastIncorrectBoard = boardSignature;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Not quite right yet. Check your entries and try again.')),
        );
      }
    }
  }

  void _submitSeed(String rawSeed) {
    final seed = int.tryParse(rawSeed);
    if (seed == null || seed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a seed of 0 or higher.')),
      );
      return;
    }
    _loadGame(seed: seed);
  }

  Future<void> _showScoreboard() async {
    try {
      final scores = await _scoreboardStore.loadScores();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _ScoreboardDialog(
          scores: scores,
          formatTime: durationToString,
          capitalize: _capitalize,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      const message = 'Could not load the scoreboard';
      _showPersistenceError(message, error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final horizontalPadding = landscape ? 24.0 : 20.0;
            final content = landscape
                ? Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: min(
                                constraints.maxHeight - 32,
                                constraints.maxWidth * 0.62,
                              ),
                            ),
                            child: SudokuBoard(
                              game: _game,
                              onCellSelected: (cell) =>
                                  _selectCell(cell.$1, cell.$2),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: min(380.0, constraints.maxWidth * 0.46),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 10),
                                _buildStatus(context),
                                const SizedBox(height: 8),
                                _buildSeedInput(context),
                                const SizedBox(height: 12),
                                _buildNumberPad(context),
                                const SizedBox(height: 8),
                                _buildActions(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildHeader(context),
                          const SizedBox(height: 12),
                          _buildStatus(context),
                          const SizedBox(height: 8),
                          _buildSeedInput(context),
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: min(
                                  600.0,
                                  constraints.maxWidth - horizontalPadding * 2,
                                ),
                              ),
                              child: SudokuBoard(
                                game: _game,
                                onCellSelected: (cell) =>
                                    _selectCell(cell.$1, cell.$2),
                              ),
                            ),
                          ),
                          _buildNumberPad(context),
                          const SizedBox(height: 12),
                          _buildActions(context),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
              ),
              Text(
                'A little space to focus.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          key: const ValueKey('scoreboard'),
          onPressed: _showScoreboard,
          tooltip: 'Scoreboard',
          icon: const Icon(Icons.emoji_events_outlined),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          key: const ValueKey('new-puzzle'),
          onPressed: _loading ? null : () => _loadGame(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('New puzzle'),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  durationToString(_game.elapsedSeconds),
                  key: const ValueKey('game-timer'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SudokuDifficulty>(
                      key: const ValueKey('difficulty'),
                      value: selectedDifficulty,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: SudokuDifficulty.values
                          .map(
                            (difficulty) => DropdownMenuItem(
                              value: difficulty,
                              child: Text(
                                _capitalize(difficulty.name),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (difficulty) {
                              if (difficulty != null &&
                                  difficulty != selectedDifficulty) {
                                _loadGame(difficulty: difficulty);
                              }
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeedInput(BuildContext context) {
    return TextField(
      key: const ValueKey('seed-input'),
      controller: _seedController,
      enabled: !_loading,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: _submitSeed,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.tag_rounded),
        labelText: 'Puzzle seed',
        hintText: 'Enter a seed to replay a puzzle',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildNumberPad(BuildContext context) => SudokuNumberPad(
        game: _game,
        onNumberSelected: _selectNumber,
      );

  Widget _buildActions(BuildContext context) => SudokuActionBar(
        game: _game,
        loading: _loading,
        onUndo: () {
          _game.undo();
          _markGameTouched();
        },
        onNotesChanged: _toggleNotes,
        onErase: () => _selectNumber(0),
      );

  String _capitalize(String value) {
    final label = value.replaceAll('_', '-');
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _ScoreboardDialog extends StatelessWidget {
  const _ScoreboardDialog({
    required this.scores,
    required this.formatTime,
    required this.capitalize,
  });

  final Map<SudokuDifficulty, List<int>> scores;
  final String Function(int) formatTime;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Best times'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final difficulty in SudokuDifficulty.values) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    capitalize(difficulty.name),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (scores[difficulty]!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No times yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (var index = 0;
                      index < scores[difficulty]!.length;
                      index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '#${index + 1}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            formatTime(scores[difficulty]![index]),
                            style: textTheme.bodyLarge?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                if (difficulty != SudokuDifficulty.values.last)
                  const Divider(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

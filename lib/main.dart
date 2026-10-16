import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:sudoku_flutter/last_game_store.dart';
import 'package:sudoku_flutter/scoreboard.dart';
import 'package:sudoku_flutter/sudoku.dart';
import 'package:sudoku_flutter/sudoku_game_controller.dart';
import 'package:sudoku_flutter/sudoku_puzzle_pool.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.puzzlePool});

  final SudokuPuzzlePool? puzzlePool;

  static const _seedColor = Color.fromARGB(255, 102, 49, 101);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          surface: const Color(0xFFF6F6F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F8),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBE8CC9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LoaderOverlay(
        child: SudokuPage(title: 'Sudoku', puzzlePool: puzzlePool),
      ),
    );
  }
}

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key, required this.title, this.puzzlePool});

  final String title;
  final SudokuPuzzlePool? puzzlePool;

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> with WidgetsBindingObserver {
  static const _elapsedCheckpointInterval = 5;

  final ScoreboardStore _scoreboardStore = ScoreboardStore();
  final LastGameStore _lastGameStore = LastGameStore();
  Future<void> _lastGameWrites = Future<void>.value();
  late final SudokuGameController _game = SudokuGameController(
    initialGame: Sudoku(difficulty: SudokuDifficulty.easy, initialise: false),
    startTimer: false,
  );
  late final SudokuPuzzlePool _puzzlePool = widget.puzzlePool ??
      SudokuPuzzlePool(
        create: (difficulty) => Sudoku.create(difficulty: difficulty),
      );
  SudokuDifficulty selectedDifficulty = SudokuDifficulty.easy;
  final TextEditingController _seedController = TextEditingController();
  bool _loading = true;
  bool _loadInProgress = false;
  bool _hasSavedGame = false;
  bool _currentGameTouched = false;
  int _lastElapsedCheckpoint = 0;
  String? _lastIncorrectBoard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.addListener(_onGameChanged);
    _puzzlePool.preloadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  Future<void> _initializeGame() async {
    Map<String, dynamic>? savedProgress;
    try {
      savedProgress = await _lastGameStore.load();
    } catch (_) {
      await _lastGameStore.clear();
    }
    if (!mounted) return;
    _hasSavedGame = savedProgress != null;
    if (savedProgress == null) {
      await _loadGame();
      return;
    }

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
      await _resumeLastGame();
    } else {
      await _loadGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _seedController.dispose();
    super.dispose();
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
      if (!_loading &&
          !_game.isComplete &&
          (_currentGameTouched || !_hasSavedGame)) {
        unawaited(_saveLastGame());
      }
    }
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
    final elapsed = _game.elapsedSeconds;
    if (_loading ||
        _game.isComplete ||
        !_hasSavedGame ||
        elapsed - _lastElapsedCheckpoint < _elapsedCheckpointInterval) {
      return;
    }
    _lastElapsedCheckpoint = elapsed;
    _lastGameWrites = _lastGameWrites
        .then((_) => _lastGameStore.saveElapsedSeconds(elapsed))
        .catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your game timer: $error')),
        );
      }
    });
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
          : await Sudoku.create(seed: seed, difficulty: nextDifficulty);
      if (!mounted) return;

      _game.load(nextInstance);
      _lastElapsedCheckpoint = 0;
      _currentGameTouched = saveAsLastGame;
      setState(() {
        selectedDifficulty = nextDifficulty;
        _lastIncorrectBoard = null;
        _loading = false;
        _seedController.text = '${nextInstance.seed}';
      });
      context.loaderOverlay.hide();
      if (saveAsLastGame) unawaited(_saveLastGame());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.loaderOverlay.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create a puzzle: $error')),
      );
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
    _currentGameTouched = true;
    unawaited(_saveLastGame());
  }

  Future<void> _saveLastGame() {
    if (_game.isComplete) return Future<void>.value();
    final progress = _game.exportProgress();
    _lastElapsedCheckpoint = _game.elapsedSeconds;
    _lastGameWrites =
        _lastGameWrites.then((_) => _lastGameStore.save(progress)).then((_) {
      if (mounted && !_hasSavedGame) {
        setState(() => _hasSavedGame = true);
      }
    }).catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your game: $error')),
        );
      }
    });
    return _lastGameWrites;
  }

  Future<void> _resumeLastGame() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    setState(() => _loading = true);
    final loaderOverlay = context.loaderOverlay;
    loaderOverlay.show();
    try {
      final progress = await _lastGameStore.load();
      if (progress == null) {
        if (mounted) {
          setState(() {
            _hasSavedGame = false;
            _loading = false;
          });
        }
        return;
      }
      final seed = progress['seed'] as int;
      final difficulty = SudokuDifficulty.values.firstWhere(
        (candidate) => candidate.name == progress['difficulty'],
      );
      final game = await Sudoku.create(seed: seed, difficulty: difficulty);
      if (!mounted) return;
      _game.load(game);
      _game.restoreProgress(progress);
      _lastElapsedCheckpoint = _game.elapsedSeconds;
      _currentGameTouched = true;
      setState(() {
        selectedDifficulty = difficulty;
        _seedController.text = '$seed';
        _lastIncorrectBoard = null;
        _hasSavedGame = true;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        await _lastGameStore.clear();
        if (!mounted) return;
        setState(() {
          _hasSavedGame = false;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resume your game: $error')),
        );
      }
    } finally {
      loaderOverlay.hide();
      _loadInProgress = false;
    }
  }

  Future<void> _clearLastGame() async {
    await _lastGameWrites;
    await _lastGameStore.clear();
    if (mounted) setState(() => _hasSavedGame = false);
  }

  Future<void> _verify() async {
    if (!_game.isFilled || _game.isComplete) return;
    if (_game.verifyAndComplete()) {
      _currentGameTouched = false;
      unawaited(_clearLastGame());
      final finishTime = _game.elapsedSeconds;
      final difficulty = _game.game.difficulty;
      int? scoreRank;
      try {
        scoreRank = await _scoreboardStore.recordTime(
          difficulty: difficulty,
          seconds: finishTime,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save your score: $error')),
          );
        }
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
            content:
                Text('Not quite right yet. Check your entries and try again.'),
          ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load the scoreboard: $error')),
      );
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
                            child: _buildBoard(context),
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
                              child: _buildBoard(context),
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

  Widget _buildBoard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      key: const ValueKey('sudoku-board'),
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 81,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9,
                ),
                itemBuilder: (context, index) {
                  final row = index ~/ 9;
                  final column = index % 9;
                  final isSelected =
                      _game.selectedRow == row && _game.selectedCol == column;
                  final isPeer = !isSelected &&
                      (_game.selectedRow == row || _game.selectedCol == column);
                  final value = _game.valueAt(row, column);
                  final cellValue = value == 0 ? '' : '$value';
                  final matchesSelectedNumber = _game.selectedNumber >= 0 &&
                      value == _game.selectedNumber;
                  final background = isSelected
                      ? colors.primaryContainer
                      : matchesSelectedNumber
                          ? colors.tertiaryContainer
                          : isPeer
                              ? colors.surfaceContainerHighest
                              : colors.surface;
                  final cellNotes = _game.notesAt(row, column);

                  return Semantics(
                    button: _game.isEditable(row, column),
                    label:
                        'Row ${row + 1}, column ${column + 1}${cellValue.isEmpty ? ', empty' : ', $cellValue'}${cellNotes.isEmpty ? '' : ', notes ${cellNotes.toList()..sort()}'}',
                    child: InkWell(
                      onTap: _game.isEditable(row, column)
                          ? () => _selectCell(row, column)
                          : null,
                      child: ColoredBox(
                        color: background,
                        child: cellNotes.isNotEmpty &&
                                _game.isEditable(row, column)
                            ? _buildNotes(context, cellNotes)
                            : Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) => Text(
                                    cellValue,
                                    style: TextStyle(
                                      fontSize:
                                          min(22, constraints.maxWidth * 0.65),
                                      fontWeight: _game.isEditable(row, column)
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: _game.isEditable(row, column)
                                          ? colors.primary
                                          : colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('sudoku-grid-lines'),
                  painter: _SudokuGridPainter(color: colors.outlineVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotes(BuildContext context, Set<int> notes) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final noteFontSize = min(15.0, constraints.maxWidth / 3 * 0.95);
        return Column(
          children: List.generate(
            3,
            (row) => Expanded(
              child: Row(
                children: List.generate(
                  3,
                  (column) {
                    final number = row * 3 + column + 1;
                    return Expanded(
                      child: Center(
                        child: Text(
                          notes.contains(number) ? '$number' : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: noteFontSize,
                            height: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberPad(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (row) => Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
          child: Row(
            children: List.generate(
              3,
              (column) {
                final number = row * 3 + column + 1;
                final selected = _game.selectedNumber == number;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: column == 0 ? 0 : 6),
                    child: _buildDigitKey(context, number, selected),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitKey(BuildContext context, int number, bool selected) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Enter $number',
      button: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('digit-$number'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectNumber(number),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                '$number',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('undo'),
                onPressed: _loading || !_game.canUndo
                    ? null
                    : () {
                        _game.undo();
                        _markGameTouched();
                      },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Undo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterChip(
                key: const ValueKey('notes-toggle'),
                selected: _game.notesEnabled,
                onSelected: _loading || _game.isComplete ? null : _toggleNotes,
                avatar: Icon(
                  _game.notesEnabled
                      ? Icons.edit_note
                      : Icons.edit_note_outlined,
                ),
                label: Text(_game.notesEnabled ? 'Notes on' : 'Notes'),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('erase'),
                onPressed: _loading || _game.isComplete
                    ? null
                    : () => _selectNumber(0),
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Erase'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

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

class _SudokuGridPainter extends CustomPainter {
  const _SudokuGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    final majorPaint = Paint()
      ..color = color
      ..strokeWidth = 2;

    for (var line = 0; line <= 9; line++) {
      final position = size.width * line / 9;
      final paint = line % 3 == 0 ? majorPaint : minorPaint;
      canvas.drawLine(
        Offset(position, 0),
        Offset(position, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, position),
        Offset(size.width, position),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SudokuGridPainter oldDelegate) =>
      color != oldDelegate.color;
}

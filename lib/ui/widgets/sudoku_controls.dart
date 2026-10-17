import 'package:flutter/material.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';

class SudokuNumberPad extends StatelessWidget {
  const SudokuNumberPad({
    super.key,
    required this.game,
    required this.onNumberSelected,
  });

  final SudokuGameController game;
  final ValueChanged<int> onNumberSelected;

  @override
  Widget build(BuildContext context) {
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
                final selected = game.selectedNumber == number;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: column == 0 ? 0 : 6),
                    child: _DigitKey(
                      number: number,
                      selected: selected,
                      onPressed: () => onNumberSelected(number),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SudokuActionBar extends StatelessWidget {
  const SudokuActionBar({
    super.key,
    required this.game,
    required this.loading,
    required this.onUndo,
    required this.onNotesChanged,
    required this.onErase,
  });

  final SudokuGameController game;
  final bool loading;
  final VoidCallback onUndo;
  final ValueChanged<bool> onNotesChanged;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('undo'),
            onPressed: loading || !game.canUndo ? null : onUndo,
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
            selected: game.notesEnabled,
            onSelected: loading || game.isComplete ? null : onNotesChanged,
            avatar: Icon(
              game.notesEnabled ? Icons.edit_note : Icons.edit_note_outlined,
            ),
            label: Text(game.notesEnabled ? 'Notes on' : 'Notes'),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('erase'),
            onPressed: loading || game.isComplete ? null : onErase,
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
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.number,
    required this.selected,
    required this.onPressed,
  });

  final int number;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
          onTap: onPressed,
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
}

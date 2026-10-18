import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';

class SudokuNumberPad extends StatelessWidget {
  const SudokuNumberPad({
    super.key,
    required this.game,
    required this.onNumberSelected,
    required this.scaleFactor,
  });

  final SudokuGameController game;
  final ValueChanged<int> onNumberSelected;
  final double scaleFactor;

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
                      scaleFactor: scaleFactor,
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
    required this.scaleFactor,
  });

  final SudokuGameController game;
  final bool loading;
  final VoidCallback onUndo;
  final ValueChanged<bool> onNotesChanged;
  final VoidCallback onErase;
  final double scaleFactor;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = TextStyle(fontSize: 15 * sqrt(scaleFactor));
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('undo'),
            onPressed: loading || !game.canUndo ? null : onUndo,
            icon: Icon(Icons.undo_rounded, size: 15 * scaleFactor),
            label: Text('Undo', style: textStyle),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(48 * scaleFactor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14 * scaleFactor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('notes-toggle'),
            onPressed: loading || game.isComplete
                ? null
                : () => onNotesChanged(!game.notesEnabled),
            icon: Icon(
              game.notesEnabled ? Icons.edit_note : Icons.edit_note_outlined,
              size: 15 * scaleFactor,
            ),
            label: Text(
              game.notesEnabled ? 'Notes on' : 'Notes off',
              style: textStyle,
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  game.notesEnabled ? colors.primaryContainer : null,
              foregroundColor:
                  game.notesEnabled ? colors.onPrimaryContainer : null,
              minimumSize: Size.fromHeight(48 * scaleFactor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14 * scaleFactor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('erase'),
            onPressed: loading || game.isComplete ? null : onErase,
            icon: Icon(Icons.backspace_outlined, size: 15 * scaleFactor),
            label: Text('Erase', style: textStyle),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  game.selectedNumber == 0 ? colors.primaryContainer : null,
              foregroundColor:
                  game.selectedNumber == 0 ? colors.onPrimaryContainer : null,
              minimumSize: Size.fromHeight(48 * scaleFactor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14 * scaleFactor),
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
    required this.scaleFactor,
  });

  final int number;
  final bool selected;
  final VoidCallback onPressed;
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textSize = 22 * sqrt(scaleFactor);
    return Semantics(
      label: 'Enter $number',
      button: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(
          14 * scaleFactor,
        ),
        child: InkWell(
          key: ValueKey('digit-$number'),
          borderRadius: BorderRadius.circular(
            14 * scaleFactor,
          ),
          onTap: onPressed,
          child: SizedBox(
            height: 48 * scaleFactor,
            child: Center(
              child: Text(
                '$number',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: textSize,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

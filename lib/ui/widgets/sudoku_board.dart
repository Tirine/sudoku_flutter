import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sudoku_flutter/game/sudoku_game_controller.dart';

class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.game,
    required this.onCellSelected,
  });

  final SudokuGameController game;
  final ValueChanged<(int, int)> onCellSelected;

  @override
  Widget build(BuildContext context) {
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
                itemBuilder: (context, index) =>
                    _buildCell(context, index, colors),
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

  Widget _buildCell(BuildContext context, int index, ColorScheme colors) {
    final row = index ~/ 9;
    final column = index % 9;
    final isEditable = game.isEditable(row, column);
    final value = game.valueAt(row, column);
    final cellValue = value == 0 ? '' : '$value';
    final notes = game.notesAt(row, column);
    final isSelected = game.selectedRow == row && game.selectedCol == column;
    final isPeer =
        !isSelected && (game.selectedRow == row || game.selectedCol == column);
    final matchesSelectedNumber =
        game.selectedNumber >= 0 && value == game.selectedNumber;
    final background = isSelected
        ? colors.primaryContainer
        : matchesSelectedNumber
            ? colors.tertiaryContainer
            : isPeer
                ? colors.surfaceContainerHighest
                : colors.surface;

    return Semantics(
      button: isEditable,
      label:
          'Row ${row + 1}, column ${column + 1}${cellValue.isEmpty ? ', empty' : ', $cellValue'}${notes.isEmpty ? '' : ', notes ${notes.toList()..sort()}'}',
      child: InkWell(
        onTap: isEditable ? () => onCellSelected((row, column)) : null,
        child: ColoredBox(
          color: background,
          child: notes.isNotEmpty && isEditable
              ? _buildNotes(context, notes)
              : Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Text(
                      cellValue,
                      style: TextStyle(
                        fontSize: min(22, constraints.maxWidth * 0.65),
                        fontWeight:
                            isEditable ? FontWeight.w500 : FontWeight.w700,
                        color: isEditable ? colors.primary : colors.onSurface,
                      ),
                    ),
                  ),
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
}

class _SudokuGridPainter extends CustomPainter {
  const _SudokuGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final thickPaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var line = 0; line <= 9; line++) {
      final position = size.width * line / 9;
      final currentPaint = line % 3 == 0 ? thickPaint : paint;
      canvas.drawLine(
          Offset(position, 0), Offset(position, size.height), currentPaint,);
      canvas.drawLine(
          Offset(0, position), Offset(size.width, position), currentPaint,);
    }
  }

  @override
  bool shouldRepaint(_SudokuGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

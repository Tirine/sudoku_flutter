# Sudoku

A Sudoku game built with Flutter. Choose a difficulty, fill the 9×9 grid, and track your solve time. Puzzles are generated from a seed, so you can replay a puzzle by entering its seed.

## Run the app

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then from this repository run:

```sh
flutter pub get
flutter run
```

To run the automated tests:

```sh
flutter test
```

## Play

Choose **Easy**, **Medium**, **Hard**, **Extreme**, or **Almost-impossible** from the level menu. The timer starts when a puzzle loads and stops when you solve it. Use **New puzzle** to start another puzzle at the selected difficulty.

### Difficulty levels

The levels are intended to reflect the solving effort a puzzle takes:

- **Easy:** mostly direct placements, such as cells with only one possible number.
- **Medium:** a mix of direct placements and scanning rows, columns, and boxes to find numbers that have only one possible location.
- **Hard:** requires more sustained candidate tracking and common patterns such as pairs or pointing and claiming.
- **Extreme:** may require advanced patterns or longer chains of deductions before a number can be placed.
- **Almost-impossible:** uses the most advanced deterministic techniques supported by the generator's logical solver. Puzzles must still have a single solution and be solvable without guessing.

These are target descriptions, not a guarantee that every puzzle requires those techniques. The generator does not assign a numeric difficulty rating; Almost-impossible puzzles are checked for unique solutions and for solvability using the logical techniques currently implemented for that level.

There are two ways to enter a number:

- **Number, then cell:** tap a digit on the number pad, then tap one or more empty squares. The selected digit stays active, so you can fill several squares with it. Tap the selected digit again to deselect it.
- **Cell, then number:** tap an empty square, then tap a digit on the number pad to enter it there.

The **Erase** button clears the selected square when a square is selected. If no square is selected, tap **Erase**, then tap a square to clear it.

### Notes

Turn on **Notes** to enter small candidate numbers in a square instead of placing a final answer. With Notes on, choose a digit and tap a square to toggle that candidate on or off. Tap **Erase** and then a square to clear all its notes. Turn Notes off to enter regular answers again. Notes are cleared when you enter a regular number in a square.

### Seeds and replay

Each puzzle displays its seed in the **Puzzle seed** field. To replay a puzzle, enter a non-negative whole number and press Enter on your keyboard. The same seed and difficulty recreate the same puzzle. Changing the difficulty while using a seed creates a different puzzle.

### Scoreboard

Open the trophy button to see the three fastest saved times for each difficulty. Times are stored on the device. Completing a puzzle records its time and shows your rank if it is among that difficulty's top three.

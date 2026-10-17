# Generator benchmarks

Run the fixed-seed generator benchmark test from the repository root:

```sh
./flutter test test/generator_benchmark_test.dart
```

The benchmark runs each case three times, reports the median generation time,
and checks that every generated puzzle is valid, has exactly one solution, and
repeats identically for the same seed. It compares each puzzle and solution
against [`generator_baseline.json`](./generator_baseline.json). The newest
measurements are written to [`results/latest.json`](./results/latest.json).

## Initial reference

Measured on 2026-10-16 with Flutter 3.47.7 / Dart 3.13.5. Values are median
generation time in milliseconds for three runs; the exact records and seed
outputs are in the baseline JSON.

| Difficulty | Seed | Median (ms) | Clues |
| --- | ---: | ---: | ---: |
| Easy | 123456 | 2.314 | 49 |
| Easy | 314159265 (pi) | 2.442 | 49 |
| Medium | 234567 | 1.862 | 41 |
| Medium | 628318531 (tau) | 1.980 | 41 |
| Hard | 345678 | 4.633 | 33 |
| Hard | 987654321 (reverse count) | 3.005 | 33 |
| Extreme | 654321 | 245.928 | 25 |
| Extreme | 789012 | 1396.298 | 23 |

Timing varies by machine and load, so it is recorded for comparison rather than
used as a pass/fail threshold. The exact seeded output and clue count are checked
against the baseline so performance changes can be reviewed without silently
changing generated boards.

To intentionally accept a seeded-output change, inspect the code and current
report first, then run:

```sh
./flutter test --dart-define=UPDATE_GENERATOR_BASELINE=true \
  test/generator_benchmark_test.dart
```

The cases cover two fixed seeds at each difficulty, including special seeds.
Keep the seed set stable when comparing performance across generator changes.

## Parallel generation

Run the sequential-versus-parallel benchmark with:

```sh
./flutter test test/generator_parallel_benchmark_test.dart
```

It generates the same eight fixed-seed boards sequentially and through the
puzzle pool with a cap of two active generations. It verifies that each puzzle
and solution match, then writes the measured elapsed times and board data to
[`results/parallel_latest.json`](./results/parallel_latest.json). Timing is
recorded for comparison and does not affect whether the test passes.

The original three-batch evaluation is preserved in
[`parallel_generation_reference.json`](./parallel_generation_reference.json).
On that Linux x64 host (16 logical processors), capped parallel generation had
a median elapsed time of 1,466 ms versus 1,740 ms sequentially, about 15.7%
less elapsed time. This is an initial reference from one machine; rerun the
benchmark on the same host when reviewing later changes.

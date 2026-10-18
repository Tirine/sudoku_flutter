# Solver allocation optimization

Measured with `./flutter test test/generator_benchmark_test.dart` before and
after the allocation changes on the same host. Each value is the median of
three runs. Timings vary with machine load; the benchmark also checks that
generated puzzles and solutions still match the stored baseline.

| Difficulty | Seed | Before (ms) | After (ms) | Change |
| --- | ---: | ---: | ---: | ---: |
| Easy | 123456 | 1.911 | 2.056 | +7.6% |
| Easy | 314159265 (pi) | 1.388 | 1.278 | -7.9% |
| Medium | 234567 | 1.235 | 0.892 | -27.8% |
| Medium | 628318531 (tau) | 1.691 | 1.191 | -29.6% |
| Hard | 345678 | 4.242 | 2.628 | -38.1% |
| Hard | 987654321 | 2.606 | 1.719 | -34.1% |
| Extreme | 654321 | 244.811 | 97.970 | -60.0% |
| Extreme | 789012 | 1401.262 | 732.127 | -47.7% |

At the time of these measurements, the logical generator validated a source
board once and reused candidate and snapshot grids across solving passes. That
logical generator has since been removed because it duplicated no-guess checks
without improving the set of techniques available in the game. The brute-force
generator still reuses its private scratch board for uniqueness checks and
restores retry state in place. These timings show end-to-end impact; no separate
allocation profiler was used, so they do not isolate allocation cost from other
work removed by the changes.

## Reuse uniqueness progress state

After introducing the reusable uniqueness board, code inspection found no
per-search candidate collections on the default row-major path. The remaining
per-check state allocation was one `_SolverProgress` object. Reusing one with
the generator reduces the eight fixed profile cases from 1,011 progress
objects to 8. The fewest-candidate solver returns its selected cell as a
row/column record; that path is not used by generation and was left unchanged.

The seeded output remained unchanged. End-to-end generation medians were within
normal run variation:

| Extreme seed | Before (ms) | After (ms) | Change |
| ---: | ---: | ---: | ---: |
| 654321 | 60.992 | 64.305 | +5.4% |
| 789012 | 646.208 | 644.268 | -0.3% |

The change reduces short-lived object creation but does not show a measurable
generation-time improvement. No VM heap snapshot was collected; allocation
counts are based on the fixed profile's uniqueness-check counts and the single
progress object constructed for each generator.


## Cached units and X-Wing bitmasks

Measured before and after caching the 27 Sudoku row, column, and box units and
replacing X-Wing position strings with integer masks. The fixed-seed generator
benchmark checks generated boards against the stored baseline. These timings are
from one before/after run on the same host, so treat the small changes as
indicative rather than conclusive.

| Extreme seed | Generation before (ms) | Generation after (ms) | Change |
| ---: | ---: | ---: | ---: |
| 654321 | 90.556 | 83.847 | -7.4% |
| 789012 | 693.468 | 667.439 | -3.8% |

The solver stage profile also showed lower logical-solve time:

| Extreme seed | Logical solve before (ms) | Logical solve after (ms) | Change |
| ---: | ---: | ---: | ---: |
| 654321 | 47.47 | 46.18 | -2.7% |
| 789012 | 70.80 | 62.81 | -11.3% |

Generated boards and solutions continued to match the stored baseline. The
profile records uniqueness time too, but uniqueness does not use the logical
solver's cached units or X-Wing matching. The generator values are medians of
three runs; the solver stage profile is one run per revision. Rerun the same
tests when making later performance comparisons; wall-clock timings vary with
host load.

## Logical-check experiment (removed)

This experiment moved the logical generator ahead of the brute-force
uniqueness check for Extreme. It was removed after the logical generator was
shown to be slower and unable to solve a broader set of puzzles than the
brute-force solver. Extreme now uses the same uniqueness check as the other
difficulties.

An earlier experiment reported these medians for a logical-first fast path.
That version rejected removals whenever the logical solver stalled, without
letting brute force confirm uniqueness. Those timings therefore came from a
different acceptance rule and are not a valid performance comparison for
uniqueness-preserving generation:

| Extreme seed | Previous order (ms) | Logical proof (ms) | Change | Clues before → after |
| ---: | ---: | ---: | ---: | ---: |
| 654321 | 88.853 | 82.243 | -7.4% | 25 → 24 |
| 789012 | 699.236 | 92.544 | -86.8% | 23 → 25 |
| Combined | 788.089 | 174.787 | -77.8% | — |

The later fallback version ran both checks after a logical stall: seed 654321
took 851 ms and seed 789012 took 849 ms, compared with 89 ms and 699 ms in the
earlier uniqueness-first run. The logical generator has now been removed, and
the fixed-seed benchmark records the new uniqueness-only outputs. Its medians
were 59.751 ms for seed 654321 and 632.910 ms for seed 789012. Timings vary by
host load and cover only two Extreme seeds.

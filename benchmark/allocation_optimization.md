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

The logical generator now validates a source board once and reuses candidate and
snapshot grids across solving passes. The generator reuses its private scratch
board for uniqueness checks and restores retry state in place. Both paths keep
caller-owned boards unchanged. These timings show end-to-end impact; no separate
allocation profiler was used, so they do not isolate allocation cost from other
work removed by the changes.

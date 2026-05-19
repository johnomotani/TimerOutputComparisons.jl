# TimerOutputsComparisons

[![Build Status](https://github.com/johnomotani/TimerOutputsComparisons.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/johnomotani/TimerOutputsComparisons.jl/actions/workflows/CI.yml?query=branch%3Amain)

Provides some helper functions to save/load TimerOutput objects, and plot
comparisons of them. This may be useful to compare performance with different
settings, or between different versions of some code.

In complex examples it may be useful to save the TimerOutput objects to files,
and then plot them as a separate post-processing step, so in the example below
we save and re-load the TimerOutput objects, even though it is possible to pass
them directly to `compare_timers()`.

Usage
-----

```julia
using TimerOutputComparisons
using TimerOutputs

delay_times = [0.1, 0.2, 0.3]

for dt ∈ delay_times
    to = TimerOutput()
    @timeit to "sleep" sleep(dt)
    filename = "foo$dt.jld"
    save_timer(filename, to)
end

compare_timers(["foo$dt.jld" for dt ∈ delay_times]...)
```

To plot only one or two quantities, use the `include` kwarg and pass one or
more of `:ncalls`, `:time` and `:allocs` to `include`. For example
`compare_timers(["foo$dt.jld" for dt ∈ delay_times]...; include=:time)`.

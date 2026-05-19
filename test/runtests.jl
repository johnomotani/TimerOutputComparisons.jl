using TimerOutputComparisons
using TimerOutputs
using Test

function dump_timer(sleeptime, outputdir)
    to = TimerOutput()
    @timeit to "sleep" sleep(sleeptime)
    filename = joinpath(outputdir, "foo$sleeptime.jld")
    save_timer(filename, to)
end
function dump_timer(sleeptime, outputdir, timer_name)
    to = TimerOutput()
    @timeit to "sleep" sleep(sleeptime)
    filename = joinpath(outputdir, "foo$sleeptime.jld")
    save_timer(filename, to, timer_name)
end

function runtests()
    @testset "TimerOutputComparisons.jl" begin
        for flatten ∈ (false, true), include ∈ (nothing, :ncalls, :time, :allocs,
                                                (:ncalls, :time), (:ncalls, :allocs),
                                                (:time, :allocs),
                                                (:allocs, :time, :ncalls))
            # This package mostly makes interactive plots, so this is primarily a smoke-test.
            outputdir = tempname()
            mkpath(outputdir)

            dump_timer(0.1, outputdir)
            dump_timer(0.5, outputdir, "bar")

            to = TimerOutput()
            @timeit to "sleep" sleep(1)

            @test isa(load_timer(joinpath(outputdir, "foo0.1.jld")), TimerOutput)
            @test isa(load_timer(joinpath(outputdir, "foo0.5.jld"), "bar"), TimerOutput)

            if include === nothing
                compare_timers(joinpath(outputdir, "foo0.1.jld"),
                               (joinpath(outputdir, "foo0.5.jld"), "bar"),
                               (to, "foo1");
                               flatten, save_as=joinpath(outputdir, "foo.png"))
            else
                compare_timers(joinpath(outputdir, "foo0.1.jld"),
                               (joinpath(outputdir, "foo0.5.jld"), "bar"),
                               (to, "foo1");
                               flatten, include, save_as=joinpath(outputdir, "foo.png"))
            end
        end
    end
end

runtests()

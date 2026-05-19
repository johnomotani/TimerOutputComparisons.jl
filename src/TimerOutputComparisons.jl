"""
TimerOutputComparisons
======================

Provides some helper functions to save/load TimerOutput objects, and plot comparisons of
them. This may be useful to compare performance with different settings, or between
different versions of some code.
"""
module TimerOutputComparisons

export save_timer, load_timer, compare_timers
# Workaround for failures when JLD is not loaded in Main, see
# https://github.com/JuliaIO/JLD.jl/issues/252
export JLD

using GLMakie
using JLD
using TimerOutputs

"""
    save_timer(filename::AbstractString, to::TimerOutput,
               timer_name::AbstractString="to")

Save `to` to a JLD file called `filename`, in a variable called `timer_name`. `filename`
should end with ".jld".
"""
function save_timer(filename::AbstractString, to::TimerOutput,
                    timer_name::AbstractString="to")
    if splitext(filename)[2] != ".jld"
        error("`filename` should end in \".jld\" so that JLD format is used. Otherwise "
              * "a TimerOutput might not be writable and re-loadable.")
    end
    JLD.save(filename, timer_name, to)
end

"""
    load_timer(filename::AbstractString,
               timer_name::AbstractString="to")::TimerOutput

Load a TimerOutput called `timer_name` from a JLD file called `filename`.
"""
function load_timer(filename::AbstractString,
                    timer_name::AbstractString="to")::TimerOutput
    if splitext(filename)[2] != ".jld"
        error("Expected `filename` to end in \".jld\" so that JLD format is used.")
    end
    to = JLD.load(filename, timer_name)
    return to
end

const possible_includes = (:ncalls, :time, :allocs)

"""
    compare_timers(timers::Union{AbstractString,Tuple{<:AbstractString,<:AbstractString},Tuple{TimerOutput,<:AbstractString}}...;
                   flatten=false, save_as=nothing, include=$possible_includes)

Make a plot comparing `timers`. For `t` in `timers`:
* if `t` is an AbstractString, load a TimerOutput from the file named `t` using
  `load_timer()`, and label it `t`.
* if `t` is a `Tuple{<:AbstractString,<:AbstractString}`, load a TimerOutput called `t[2]`
  from the file named `t[1]` using `load_timer()`, and label it `t[1] * ":" * t[2]`.
* if `t` is a `Tuple{TimerOutput,<:AbstractString}`, use the TimerOutput `t[1]` and label
  it `t[2]`.

We assume that the TimerOutput objects in `timers` contain (mostly) the same timers,
otherwise this comparison will not make much sense.

If `flatten=true`, the TimerOutput objects are flattened with `TimerOutputs.flatten()`.

If a file-name is passed to `save_as` the plots are saved instead of being displayed
interactively. For example, `save_as="foo.png"` would result in the plots being saved as
"foo_ncalls.png", "foo_time.png", and "foo_allocs.png".

To plot only one or two quantities, pass one or more of `:ncalls`, `:time` and `:allocs`
to `include`, for example `include=:time`.
"""
compare_timers

function compare_timers(timers::Union{AbstractString,<:Tuple{AbstractString,AbstractString},<:Tuple{TimerOutput,AbstractString}}...; kwargs...)
    function get_timer(t)::Tuple{TimerOutput,String}
        if t isa Tuple{TimerOutput,<:AbstractString}
            return (t[1], String(t[2]))
        elseif t isa AbstractString
            return (load_timer(t), splitext(String(t))[1])
        elseif t isa Tuple{<:AbstractString,<:AbstractString}
            return (load_timer(t...), splitext(String(t[1]))[1] * ":" * String(t[2]))
        else
            error("Unsupported type $(typeof(t)) for t=$t.")
        end
    end
    return compare_timers(Tuple(get_timer(t) for t ∈ timers)...; kwargs...)
end
function compare_timers(timers::Tuple{TimerOutput,String}...;
                        flatten=false, save_as=nothing, include=possible_includes)

    if isa(include, Symbol)
        include = (include,)
    end
    for i ∈ include
        if i ∉ possible_includes
            error("'$i' is not a valid entry in include. Possible values are "
                  * "$possible_includes.")
        end
    end
    if flatten
        timers = map(t->(TimerOutputs.flatten(t[1]), t[2]), timers)
    end

    to_list = [t[1] for t ∈ timers]
    x_values = [t[2] for t ∈ timers]

    # Get names of all timers to plot.
    timer_names = Vector{String}[]
    function extract_names!(t, name)
        if !isempty(name) && name ∉ timer_names
            push!(timer_names, name)
        end
        inner_timers = t.inner_timers
        if !isempty(inner_timers)
            for k ∈ keys(inner_timers)
                new_name = copy(name)
                push!(new_name, k)
                extract_names!(t[k], new_name)
            end
        end
        return nothing
    end
    for t ∈ to_list
        extract_names!(t, String[])
    end

    xticks = (1:length(x_values), x_values)
    if :ncalls ∈ include
        fig_ncalls = Figure()
        ax_ncalls = Axis(fig_ncalls[1,1]; xticks=xticks, ylabel="ncalls")
    else
        fig_ncalls = nothing
        ax_ncalls = nothing
    end
    if :time ∈ include
        fig_time = Figure()
        ax_time = Axis(fig_time[1,1]; xticks=xticks, ylabel="time (ms)")
    else
        fig_time = nothing
        ax_time = nothing
    end
    if :allocs ∈ include
        fig_allocs = Figure()
        ax_allocs = Axis(fig_allocs[1,1]; xticks=xticks, ylabel="allocated (kB)")
    else
        fig_allocs = nothing
        ax_allocs = nothing
    end

    for name ∈ timer_names
        plot_single_timer!(ax_ncalls, ax_time, ax_allocs, to_list, name, xticks)
    end

    for (fig, ax) in zip((fig_ncalls, fig_time, fig_allocs), (ax_ncalls, ax_time, ax_allocs))
        if fig !== nothing
            # Ensure the first row width is 3/4 of the column width so that the plot does not get
            # squashed by the legend
            rowsize!(fig.layout, 1, Aspect(1, 3/4))

            Legend(fig[2,1], ax; tellwidth=false, tellheight=true)

            resize_to_layout!(fig)
        end
    end

    if save_as === nothing
        backend = Makie.current_backend()
        for fig in (fig_ncalls, fig_time, fig_allocs)
            if fig !== nothing
                DataInspector(fig)
                display(backend.Screen(), fig)
            end
        end
    else
        prefix, suffix = splitext(save_as)
        if fig_ncalls !== nothing
            save(prefix * "_ncalls" * suffix, fig_ncalls)
        end
        if fig_time !== nothing
            save(prefix * "_time" * suffix, fig_time)
        end
        if fig_allocs !== nothing
            save(prefix * "_allocs" * suffix, fig_allocs)
        end
    end

    return fig_ncalls, fig_time, fig_allocs
end

function get_single_timer(to::TimerOutput, name::Vector{String})
    for n ∈ name
        if n ∈ keys(to.inner_timers)
            to = to[n]
        else
            return nothing
        end
    end
    return to
end

function plot_single_timer!(ax_ncalls, ax_time, ax_allocs, to_list, name::Vector{String},
                            xticks)
    this_timer_list = [get_single_timer(to, name) for to ∈ to_list]
    label = join(name, ":")

    xtick_values = xticks[2]
    if ax_ncalls !== nothing
        ncalls_values = [t === nothing ? NaN : TimerOutputs.ncalls(t) for t ∈ this_timer_list]
        lines!(ax_ncalls, ncalls_values;
               label,
               inspector_label=(self,i,p) -> "$(self.label[])\n$(xtick_values[round(Int64, p[1])]): ncalls=$(ncalls_values[round(Int64, p[1])])")
    end

    # Convert times from ns to ms.
    if ax_time !== nothing
        time_values = [t === nothing ? NaN : TimerOutputs.time(t) * 1.0e-6 for t ∈ this_timer_list]
        lines!(ax_time, time_values;
               label,
               inspector_label=(self,i,p) -> "$(self.label[])\n$(xtick_values[round(Int64, p[1])]): time=$(time_values[round(Int64, p[1])]) ms")
    end

    if ax_allocs !== nothing
        allocs_values = [t === nothing ? NaN : TimerOutputs.allocated(t) / 1024 for t ∈ this_timer_list]
        lines!(ax_allocs, allocs_values;
               label,
               inspector_label=(self,i,p) -> "$(self.label[])\n$(xtick_values[round(Int64, p[1])]): allocs=$(allocs_values[round(Int64, p[1])]) kB")
    end

    return nothing
end

end

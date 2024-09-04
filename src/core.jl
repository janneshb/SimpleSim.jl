export simulate
"""
    simulate(model; kwargs...)

Runs the simulation for the given `model`.

Returns a `NamedTuple` with all time-series information about the simulation.

# Mandatory Keyword Arguments
- `T`: Total time of the simulation. Mand

# Optional Keyword Arguments
- `uc`: Expects a function `(t) -> u` defining the input to a continuous-time model at time `t`. Defaults to `(t) -> nothing`.
- `ud`: Expects a function `(t) -> u` defining the input to a discrete-time model at time `t`. Defaults to `(t) -> nothing`.
- `Δt_max`: Maximum step size used for continuous-time model integration. Defaults to `DEFAULT_Δt` set in `SimpleSim.jl`.
- `t0`: Initial time. Defaults to `0 // 1`.
- `xc0`: Initial state for continuous-time model. Overwrites any initial state defined in the model itself. Defaults to `nothing`.
- `xd0`: Initial state for discrete-time model. Overwrites any initial state defined in the model itself. Defaults to `nothing`.
- `integrator`: Integration method to be used for continuous-time models. Defaults to `RK4.`

These options can be passed to the `simulate` function as the `integrator` keyword argument:
```julia
@enum SimpleSimIntegrator RK4 = 1 Euler = 2 Heun = 3 RKF45 = 4
```
"""
function simulate(
    model;
    T,
    uc = (t) -> nothing,
    ud = (t) -> nothing,
    Δt_max = DEFAULT_Δt,
    t0 = 0 // 1 * oneunit(T),
    xc0 = nothing, # note: this is only valid for the top-level model. Also helpful if a stand-alone model is simulated
    xd0 = nothing,
    integrator = RK4,
)

    # get supposed step size and end of simulation
    Δt_max = Δt_max === nothing ? oneunit(T) * DEFAULT_Δt : check_rational(Δt_max)
    T = check_rational(T)
    t0 = check_rational(t0)

    # find smallest time-step
    Δt_max = find_min_Δt(model, Δt_max, Δt_max)
    DEBUG && println("Using Δt = $Δt_max for continuous-time models.")

    # if RKF45 is used, times are kept as floats instead of Rationals to avoid overflow
    if integrator == RKF45
        T = float(T)
        t0 = float(t0)
        Δt_max = float(Δt_max)
    end

    # build callable structure to mimic the model tree
    model_working_copy = init_working_copy(
        model,
        t0 = t0,
        Δt = Δt_max,
        uc0 = uc(t0),
        ud0 = ud(t0),
        xc0 = xc0,
        xd0 = xd0,
        integrator = integrator,
        T = T,
    ) # TODO: find better variable name for model_working_copy

    # simulate all systems that are due now
    t = t0
    simulation_is_running = true
    while simulation_is_running
        simulation_is_running, t = loop!(model_working_copy, uc, ud, t, Δt_max, T)
    end

    DEBUG && println("Simulation has terminated.")
    DEBUG && println("Processing data...")
    out = post_process(model_working_copy)
    DEBUG && println("Done!")
    return out
end

# the main simulation loop
function loop!(model_working_copy, uc, ud, t, Δt_max, T)
    t_next = t + Δt_max
    (Δt, xc, yc, updated_state_ct) =
        model_working_copy.callable_ct!(uc(t), t_next, model_working_copy)
    t_next = min(t_next, t + Δt)
    (xd, yd, updated_state_dt) =
        model_working_copy.callable_dt!(ud(t), t_next, model_working_copy)

    if t_next > T # end of simulation
        return false, T
    end

    DEBUG &&
        DISPLAY_PROGRESS &&
        div(t_next, PROGRESS_SPACING * oneunit(Δt)) !=
        div(t_next - Δt, PROGRESS_SPACING * oneunit(Δt)) ?
    println(
        "t = ",
        round(float(t_next), digits = max(-floor(Int, log10(PROGRESS_SPACING)), 0)),
    ) : nothing
    return true, t_next
end

# Calls a model (runs it, if its due) and returns its output. Should be used within yc and yd.
export @call!, @call_ct!, @call_dt!
"""
    @call! model u

The `@call!` macro is crucial for running simulations with submodels.
In the parent model's `yc` or `yd` function every one of its submodels must be called using `@call!`.
Otherwise the submodels will not be updated.

Returns the output of `model` after the update. Use [`@state`](@ref) after calling `@call!` to access the new state.

# Example
```julia
function yc_parent_model(x, u, p, t; models)
    # ...
    y_child = @call! models[1] u_child
    # ...
end
```

_Note:_ The `@call!` must not be used inside a dynamics (`fc` / `fd`) function. This will throw an error.
If you need access to a submodels output/state inside your parent model's dynamics function use [`@out`](@ref) / [`@state`](@ref).
"""
macro call!(model, u)
    quote
        model_to_call = $(esc(model))
        t = $(esc(:t))
        if isHybrid(model_to_call)
            @error "@call! is ambiguous for hybrid systems. Please specify using @call_ct! or @call_dt!."
        elseif isCT(model_to_call)
            @call_ct! model_to_call $(esc(u))
        elseif isDT(model_to_call)
            @call_dt! model_to_call $(esc(u))
        end
    end
end

"""
    @call_ct! model u

This macro should be used instead of `@call!` for calling the continuous-time dynamics of a hybrid model. This prevents ambiguity.
See [`@call!`](@ref).
"""
macro call_ct!(model, u)
    quote
        MODEL_CALLS_DISABLED &&
            @error "@call! should not be called in the dynamics or step function. Use @out_ct and @out_dt to access the previous state instead (or @out in umambiguous cases)."

        model_to_call = $(esc(model))
        (Δt, xc, yc, updated_state) =
            model_to_call.callable_ct!($(esc(u)), $(esc(:t)), model_to_call)
        yc
    end
end

"""
    @call_dt! model u

This macro should be used instead of `@call!` for calling the discrete-time dynamics of a hybrid model. This prevents ambiguity.
See [`@call!`](@ref).
"""
macro call_dt!(model, u)
    quote
        MODEL_CALLS_DISABLED &&
            @error "@call! should not be called in the dynamics or step function. Use @out_ct and @out_dt to access the previous state instead (or @out in umambiguous cases)."

        model_to_call = $(esc(model))
        (xd, yd, updated_state) =
            model_to_call.callable_dt!($(esc(u)), $(esc(:t)), model_to_call)
        yd
    end
end

function model_callable_ct!(uc, t, model, model_working_copy, Δt, integrator, T)
    context = @context # Warn if we are still in DT context
    if context === ContextDT::SimulationContext
        @warn "You are calling a CT model (id $(model_working_copy.model_id)) from within a DT model. This should not be done and will lead to unexpected results"
    end

    xc_next = model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end]
    yc_next = model_working_copy.ycs === nothing ? nothing : model_working_copy.ycs[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)
    Δt_actual = Δt

    @ct
    updated_state = false
    if due(model_working_copy, t)
        xc_next, Δt_actual = step_ct(
            Δt,
            model.fc,
            model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end],
            uc,
            model.p,
            model_working_copy.tcs[end],
            submodels;
            integrator = integrator,
        )
        t_next = model_working_copy.tcs[end] + Δt_actual

        if hasproperty(model, :zc) &&
           model.zc !== nothing &&
           model.zc(xc_next, model.p, t_next) < -model_working_copy.zero_crossing_prec
            # Initialize bisection algorithm
            xc_lower = model_working_copy.xcs[end]
            t_lower = model_working_copy.tcs[end]
            t_upper = t_next

            # Run bisection until zero crossing precision is met, always use RK4 for this
            while true
                try
                    Δt_bi = (t_upper - t_lower) / 2
                    xc_bi, _ = step_ct(
                        Δt_bi,
                        model.fc,
                        xc_lower,
                        uc,
                        model.p,
                        t_lower,
                        submodels;
                        integrator = RK4,
                    )
                    zc_bi = model.zc(xc_bi, model.p, t_lower + Δt_bi)

                    if zc_bi < -model_working_copy.zero_crossing_prec / 2
                        # t_lower + Δt_bi still leads to zero crossing
                        t_upper = t_lower + Δt_bi
                    elseif zc_bi > model_working_copy.zero_crossing_prec / 2
                        # t_lower + Δt_bi doesn't lead to zero crossing anymore
                        t_lower = t_lower + Δt_bi
                        xc_lower = xc_bi
                    else
                        t_next = t_lower + Δt_bi
                        xc_next = xc_bi
                        break # termination of algorithm if within +/-(zero_crossing_prec/2)
                    end
                catch
                    @warn "Zero-crossing precision could not be met."
                    break # probably a Rational overflow occured. Accept current precision but print warning
                end
            end

            xc_next = model.zc_exec(xc_next, uc, model.p, t_next) # apply zero crossing change
            yc_next =
                length(submodels) > 0 ?
                model.yc(xc_next, uc, model.p, t_next; models = submodels) :
                model.yc(xc_next, uc, model.p, t_next)
            Δt_post_zc = model_working_copy.tcs[end] + Δt_actual - t_next
            update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next, T)

            # fill in the remaining time of Δt to avoid Rational overflow in future iterations
            xc_next, _ = step_ct(
                Δt_post_zc,
                model.fc,
                xc_next,
                uc,
                model.p,
                t_next,
                submodels;
                integrator = RK4,
            )
            t_next += Δt_post_zc
        end
        yc_next =
            length(submodels) > 0 ?
            model.yc(xc_next, uc, model.p, t_next; models = submodels) :
            model.yc(xc_next, uc, model.p, t_next)
        update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next, T)
        updated_state = true
    end
    @call_completed
    return (Δt_actual, xc_next, yc_next, updated_state)
end

function model_callable_dt!(ud, t, model, model_working_copy, T)
    @dt
    xd_next = model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end]
    yd_next = model_working_copy.yds === nothing ? nothing : model_working_copy.yds[end]
    wd_next = model_working_copy.wds === nothing ? nothing : model_working_copy.wds[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    updated_state = false
    if due(model_working_copy, t)
        wd_next =
            hasproperty(model, :wd) ?
            model.wd(xd_next, ud, model.p, t, model_working_copy.rng_dt) : nothing
        xd_next = step_dt(
            model.fd,
            model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end],
            ud,
            model.p,
            t,
            submodels,
            wd_next,
        )
        yd_kwargs = length(submodels) > 0 ? (models = submodels,) : ()
        yd_kwargs = wd_next === nothing ? yd_kwargs : (yd_kwargs..., w = wd_next)
        yd_next = model.yd(xd_next, ud, model.p, t; yd_kwargs...)
        update_working_copy_dt!(model_working_copy, t, xd_next, yd_next, wd_next, T)
        updated_state = true
    end
    @call_completed
    return (xd_next, yd_next, updated_state)
end

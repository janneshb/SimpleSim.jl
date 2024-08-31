module SimpleSim

using Random
import Base.push!, Base.@inline, Base.gcd

global DEFAULT_Δt = 1 // 100 # default step size for CT systems, must be rational!
global Δt_MIN = 1 // 1_000_000
global DEFAULT_zero_crossing_precision = 1e-5
global RKF45_REL_TOLERANCE = 1e-6
global RKF45_MIN_ABS_ERR = 1e-7
global DEBUG = true
global DISPLAY_PROGRESS = false
global PROGRESS_SPACING = 1 // 1 # in the same unit as total time T
global BASE_RNG = MersenneTwister

#########################
#       Utilities       #
#########################
@inline check_rational(x) = _check_rational(x)
@inline _check_rational(x::Rational{Int64}) = x
@inline _check_rational(x::Int) = x
@inline _check_rational(x::AbstractFloat) = begin
    @error "Timesteps and durations should be given as `Rational` to avoid timing errors."
    x
end
@inline _check_rational(x) = oneunit(x) * _check_rational(x.val) # assume it's a Unitful.jl Quantity
gcd(x, y) = oneunit(x) * Base.gcd(x.val, y.val) # for Unitful.jl Quantities

# @quiet macro disables DEBUG and DISABLE_PROGRESS output for the command given to it
macro quiet(command)
    quote
        exDEBUG = DEBUG
        exDISPLAY_PROGRESS = DISPLAY_PROGRESS
        global DEBUG = false
        global DISPLAY_PROGRESS = false
        $(esc(command))
        global DEBUG = exDEBUG
        global DISPLAY_PROGRESS = exDISPLAY_PROGRESS
    end
end

# @safeguard_on / @safeguard_off are macros for internal use only to protect models from being called
macro safeguard_on()
    :(global MODEL_CALLS_DISABLED = true)
end
macro safeguard_off()
    :(global MODEL_CALLS_DISABLED = false)
end

# @ct / @dt switches the context to CT/DT
# @context returns the current context
@enum SimulationContext ContextUnknown = 0 ContextCT = 1 ContextDT = 2
macro ct()
    :(global CONTEXT = ContextCT::SimulationContext)
end
macro dt()
    :(global CONTEXT = ContextDT::SimulationContext)
end
macro call_completed()
    :(global CONTEXT = ContextUnknown::SimulationContext)
end
macro context()
    :(CONTEXT)
end

# Model Type
@enum ModelType TypeUnknown = 0 TypeCT = 1 TypeDT = 2 TypeHybrid = 3

# DO NOT CHANGE THESE GLOBAL VARIABLES
global MODEL_CALLS_DISABLED = false
global CONTEXT = ContextUnknown::SimulationContext
global MODEL_COUNT = 0

# For model tree printing, see model_tree(model)
printI = "│"
printT = '├'
printLine = '─'
printL = "└"
printSpace = " "

# initializes the "working copy" of the model that contains the states and outputs over the course of the simulation
function init_working_copy(
    model;
    t0 = nothing,
    Δt = nothing,
    uc0 = nothing,
    ud0 = nothing,
    xc0 = nothing,
    xd0 = nothing,
    level = 0,
    recursive = false,
    structure_only = false,
    fieldname = "top-level model",
    integrator = RK4,
    T = nothing,
)
    function build_sub_tree(models::NamedTuple)
        return NamedTuple{keys(models)}((
            (
                init_working_copy(
                    m_i,
                    t0 = t0,
                    Δt = Δt,
                    uc0 = nothing,
                    ud0 = nothing;
                    level = level + 1,
                    recursive = true,
                    structure_only = structure_only,
                    fieldname = ".$fieldname_i",
                    T = T,
                ) for (m_i, fieldname_i) in zip(models, fieldnames(typeof(models)))
            )...,
        ))
    end

    function build_sub_tree(models::Tuple)
        return (
            (
                init_working_copy(
                    m_i,
                    t0 = t0,
                    Δt = Δt,
                    uc0 = nothing,
                    ud0 = nothing;
                    level = level + 1,
                    recursive = true,
                    structure_only = structure_only,
                    fieldname = "($fieldname_i)",
                    T = T,
                ) for (m_i, fieldname_i) in zip(models, fieldnames(typeof(models)))
            )...,
        )
    end

    function build_sub_tree(models::Vector)
        return [
            init_working_copy(
                m_i,
                t0 = t0,
                Δt = Δt,
                uc0 = nothing,
                ud0 = nothing;
                level = level + 1,
                recursive = true,
                structure_only = structure_only,
                fieldname = "[$i]",
                T = T,
            ) for (i, m_i) in enumerate(models)
        ]
    end

    model_name = "$fieldname / $(Base.typename(typeof(model)).wrapper)"
    global MODEL_COUNT = recursive ? MODEL_COUNT + 1 : 1
    model_id = MODEL_COUNT

    # TODO: add support for StaticArrays and better type inference
    DEBUG && level == 0 ? println("Initializing models at t = ", float(t0)) : nothing
    DEBUG && level == 0 ?
    println(
        "Top-level model is ",
        isCT(model) ? "CT." : (isDT(model) ? "DT." : "hybrid."),
    ) : nothing
    sub_tree = (;)
    if hasproperty(model, :models) && model.models !== nothing
        sub_tree = build_sub_tree(model.models)
    end

    rng_dt =
        hasproperty(model, :wd) &&
        hasproperty(model, :wd_seed) &&
        model.wd_seed !== nothing ? BASE_RNG(model.wd_seed) : BASE_RNG(model_id)

    xc0 =
        hasproperty(model, :xc0) && model.xc0 !== nothing ?
        (xc0 === nothing ? model.xc0 : xc0) : nothing
    uc0 =
        uc0 === nothing ?
        (hasproperty(model, :uc0) && model.uc0 !== nothing ? model.uc0 : nothing) : uc0
    ycs0 =
        !structure_only && hasproperty(model, :yc) && model.yc !== nothing ?
        (
            length(sub_tree) > 0 ? [model.yc(xc0, uc0, model.p, t0; models = sub_tree)] :
            [model.yc(xc0, uc0, model.p, t0)]
        ) : nothing

    xd0 =
        hasproperty(model, :xd0) && model.xd0 !== nothing ?
        (xd0 === nothing ? model.xd0 : xd0) : nothing
    ud0 =
        uc0 === nothing ?
        (hasproperty(model, :ud0) && model.ud0 !== nothing ? model.ud0 : nothing) : ud0
    wd0 = hasproperty(model, :wd) ? model.wd(xd0, ud0, model.p, t0, rng_dt) : nothing
    yd_kwargs = length(sub_tree) > 0 ? (models = sub_tree,) : ()
    yd_kwargs = hasproperty(model, :wd) ? (yd_kwargs..., w = wd0) : yd_kwargs
    yds0 =
        !structure_only && hasproperty(model, :yd) && model.yd !== nothing ?
        [model.yd(xd0, ud0, model.p, t0; yd_kwargs...)] : nothing

    type = begin
        temp_type = TypeUnknown::ModelType
        if isCT(model)
            temp_type = TypeCT::ModelType
        elseif isDT(model)
            temp_type = TypeDT::ModelType
        end
        if isHybrid(model)
            temp_type = TypeHybrid::ModelType
        end
        temp_type
    end

    return (
        name = model_name,
        model_id = model_id,
        type = type,
        callable_ct! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_ct!(u, t, model, model_working_copy, Δt, integrator, T) :
                       nothing,
        callable_dt! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_dt!(u, t, model, model_working_copy, T) : nothing,
        Δt = !structure_only && hasproperty(model, :Δt) && model.Δt !== nothing ? model.Δt :
             Δt,
        zero_crossing_prec = !structure_only &&
                             hasproperty(model, :zero_crossing_precision) &&
                             model.zero_crossing_precision !== nothing ?
                             model.zero_crossing_precision :
                             DEFAULT_zero_crossing_precision,
        # the following store the latest state
        tcs = !structure_only && hasproperty(model, :yc) && model.yc !== nothing ? [t0] :
              nothing,
        xcs = !structure_only &&
              hasproperty(model, :fc) &&
              model.fc !== nothing &&
              xc0 !== nothing ? [xc0] : nothing,
        ycs = ycs0,
        tds = !structure_only && hasproperty(model, :yd) && model.yd !== nothing ? [t0] :
              nothing,
        xds = !structure_only &&
              hasproperty(model, :fd) &&
              model.fd !== nothing &&
              xd0 !== nothing ? [xd0] : nothing,
        yds = yds0,
        wds = !structure_only && hasproperty(model, :wd) ?
              [model.wd(xd0, ud0, model.p, t0, rng_dt)] : nothing,
        rng_dt = rng_dt,
        models = sub_tree,
    )
end

# adds an entry (tc, xc, yc) to the working copy of the model
function update_working_copy_ct!(model_working_copy, t, xc, yc, T)
    if t > T
        return
    end
    push!(model_working_copy.tcs, eltype(model_working_copy.tcs)(t)) # always store the time if the model was called
    try
        xc !== nothing ? push!(model_working_copy.xcs, eltype(model_working_copy.xcs)(xc)) :
        nothing
    catch
        @error "Could not update CT state evolution. Please check your state variables for type consistency"
    end
    try
        yc !== nothing ? push!(model_working_copy.ycs, eltype(model_working_copy.ycs)(yc)) :
        nothing
    catch
        @error "Could not update CT output evolution. Please check your output variables for type consistency"
    end
end

# adds an entry (td, xd, yd) to the working copy of the model
function update_working_copy_dt!(model_working_copy, t, xd, yd, wd, T)
    if t > T
        return
    end
    push!(model_working_copy.tds, eltype(model_working_copy.tds)(t)) # always store the time if the model was called
    try
        xd !== nothing ? push!(model_working_copy.xds, eltype(model_working_copy.xds)(xd)) :
        nothing
    catch
        @error "Could not update DT state evolution. Please check your state variables for type consistency"
    end
    try
        yd !== nothing ? push!(model_working_copy.yds, eltype(model_working_copy.yds)(yd)) :
        nothing
    catch
        @error "Could not update DT output evolution. Please check your output variables for type consistency"
    end
    try
        wd !== nothing ? push!(model_working_copy.wds, eltype(model_working_copy.wds)(wd)) :
        nothing
    catch
        @error "Could not update DT random draw evolution. Please check your random variables for type consistency"
    end
end

# reduce output and cast time series into matrix form
function post_process(out)
    function post_process_submodels(models::NamedTuple)
        return NamedTuple{keys(models)}(((post_process(m_i) for m_i in models)...,))
    end

    function post_process_submodels(models::Tuple)
        return ((post_process(m_i) for m_i in models)...,)
    end

    function post_process_submodels(models::Vector)
        return [post_process(m_i) for m_i in models]
    end

    return (
        model_id = out.model_id,
        Δt = hasproperty(out, :Δt) && out.Δt !== nothing ? out.Δt : Δt,
        tcs = out.tcs,
        xcs = out.xcs !== nothing ? reduce(vcat, transpose.(out.xcs)) : nothing,
        ycs = out.ycs !== nothing ? reduce(vcat, transpose.(out.ycs)) : nothing,
        tds = out.tds,
        xds = out.xds !== nothing ? reduce(vcat, transpose.(out.xds)) : nothing,
        yds = out.yds !== nothing ? reduce(vcat, transpose.(out.yds)) : nothing,
        wds = out.wds !== nothing ? reduce(vcat, transpose.(out.wds)) : nothing,
        models = post_process_submodels(out.models),
    )
end

####################
#       Core       #
####################
# entry hook for running a simuation
export simulate
function simulate(
    model;
    T,
    uc = (t) -> nothing,
    ud = (t) -> nothing,
    Δt_max = DEFAULT_Δt,
    t0 = 0 // 1 * oneunit(T),
    xc0 = nothing, # note: this is only valid for the top-level model. Also helpful if a stand-alone model is simulated
    xd0 = nothing,
    x0 = nothing,
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

    # process initial state, if given
    if x0 !== nothing
        @assert xc0 === nothing && xd0 === nothing
        xd0 = x0
        xc0 = x0
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
macro call!(model, u)
    # TODO: there is a way to simplify this
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

# Returns the latest output of a model without running it. For use within fc and fd.
export @out, @out_ct, @out_dt
macro out(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            @error "@out is ambiguous for hybrid systems. Please specify using @out_ct or @out_dt."
        elseif isCT(model_to_call)
            @out_ct model_to_call
        elseif isDT(model_to_call)
            @out_dt model_to_call
        end
    end
end

macro out_ct(model)
    quote
        $(esc(model)).ycs[end]
    end
end

macro out_dt(model)
    quote
        $(esc(model)).yds[end]
    end
end

# Returns the latest state of a model without running it.
export @state, @state_ct, @state_dt
macro state(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            @error "@state is ambiguous for hybrid systems. Please specify using @state_ct or @state_dt."
        elseif isCT(model_to_call)
            @state_ct model_to_call
        elseif isDT(model_to_call)
            @state_dt model_to_call
        end
    end
end

macro state_ct(model)
    quote
        $(esc(model)).xcs[end]
    end
end

macro state_dt(model)
    quote
        $(esc(model)).xds[end]
    end
end

##############################
#       Model Analysis       #
##############################
function isCT(model)
    return (
        hasproperty(model, :fc) &&
        hasproperty(model, :yc) &&
        model.fc !== nothing &&
        model.yc !== nothing
    ) || (hasproperty(model, :type) && model.type == TypeCT::ModelType)
end

function isDT(model)
    return (
        hasproperty(model, :fd) &&
        hasproperty(model, :yd) &&
        hasproperty(model, :Δt) &&
        model.fd !== nothing &&
        model.yd !== nothing &&
        model.Δt !== nothing
    ) || (hasproperty(model, :type) && model.type == TypeDT::ModelType)
end

function isHybrid(model)
    return (
        (
            hasproperty(model, :fd) &&
            hasproperty(model, :fc) &&
            hasproperty(model, :yd) &&
            hasproperty(model, :yc) &&
            hasproperty(model, :Δt)
        ) && (
            model.fd !== nothing &&
            model.fc !== nothing &&
            model.yd !== nothing &&
            model.yc !== nothing &&
            model.Δt !== nothing
        )
    ) || (hasproperty(model, :type) && model.type == TypeHybrid::ModelType)
end

function due(model, t)
    # TODO: this can be simplified
    context = @context
    if isCT(model) && context == ContextCT::SimulationContext
        return model.tcs[end] < t # CT models can always be updated if time has progressed
    end
    if isDT(model) && context == ContextDT::SimulationContext
        return model.tds[end] + model.Δt <= t
    end
    if isHybrid(model)
        # TODO: this might not work as it's supposed to
        if context == ContextCT::SimulationContext
            return model.tcs[end] < t # CT models can always be updated if time has progressed
        elseif context == ContextDT::SimulationContext
            return model.tds[end] + model.Δt <= t
        else
            @error "Could not determine if the model is due to update."
        end
    end
    return false
end

# finds the minimum step size across all models and submodels (recursively)
function find_min_Δt(model, Δt_prev, Δt_max)
    Δt = Δt_prev
    if hasproperty(model, :Δt) && model.Δt !== nothing
        Δt = gcd(Δt, check_rational(model.Δt))
    end

    if hasproperty(model, :models) && model.models !== nothing
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt, Δt_max)
        end
    end
    return gcd(Δt, check_rational(oneunit(Δt) * Δt_max))
end

###########################
#       Integrators       #
###########################
export SimpleSimIntegrator, RK4, Euler, Heun, RKF45
@enum SimpleSimIntegrator RK4 = 1 Euler = 2 Heun = 3 RKF45 = 4

# Fourth-order Runge-Kutta method
# https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods
function step_rk4(Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    _fc =
        length(submodel_tree) > 0 ?
        (x, u, p, t, models) -> fc(x, u, p, t; models = models) :
        (x, u, p, t, _) -> fc(x, u, p, t)
    k1 = _fc(x, u, p, t, submodel_tree)
    k2 = _fc(x + k1 * Δt / 2, u, p, t + Δt / 2, submodel_tree)
    k3 = _fc(x + k2 * Δt / 2, u, p, t + Δt / 2, submodel_tree)
    k4 = _fc(x + k3 * Δt, u, p, t + Δt, submodel_tree)
    @safeguard_off
    return x + Δt * (k1 + 2 * k2 + 2 * k3 + k4) / 6, Δt
end

# explicit trapezoidal rule / Heun's method
# https://en.wikipedia.org/wiki/Heun%27s_method
function step_heun(Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    _fc =
        length(submodel_tree) > 0 ?
        (x, u, p, t, models) -> fc(x, u, p, t; models = models) :
        (x, u, p, t, _) -> fc(x, u, p, t)
    k1 = _fc(x, u, p, t, submodel_tree)
    k2 = _fc(x + k1 * Δt, u, p, t + Δt, submodel_tree)
    @safeguard_off
    return x + (k1 + k2) * Δt / 2, Δt
end

# classic (forward) Euler method
# https://en.wikipedia.org/wiki/Euler_method
function step_euler(Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    k = length(submodel_tree) > 0 ? fc(x, u, p, t, models = submodel_tree) : fc(x, u, p, t)
    @safeguard_off
    return x + Δt * k, Δt
end

# Runge-Kutta-Fehlberg method / RKF45
# https://en.wikipedia.org/wiki/Runge–Kutta–Fehlberg_method
# https://maths.cnam.fr/IMG/pdf/RungeKuttaFehlbergProof.pdf
function step_rkf45(Δt, fc, x, u, p, t, submodel_tree)
    Δt = float(Δt)
    @safeguard_on
    _fc =
        length(submodel_tree) > 0 ?
        (x, u, p, t, models) -> fc(x, u, p, t; models = models) :
        (x, u, p, t, _) -> fc(x, u, p, t)
    k1 = Δt * _fc(x, u, p, t, submodel_tree)
    k2 = Δt * _fc(x + k1 / 4, u, p, t + Δt / 4, submodel_tree)
    k3 = Δt * _fc(x + 3 * k1 / 32 + 9 * k2 / 32, u, p, t + 3 * Δt / 8, submodel_tree)
    k4 =
        Δt * _fc(
            x + 1932 * k1 / 2197 - 7200 * k2 / 2197 + 7296 * k3 / 2197,
            u,
            p,
            t + 12 * Δt / 13,
            submodel_tree,
        )
    k5 =
        Δt * _fc(
            x + 439 * k1 / 216 - 8 * k2 + 3680 * k3 / 513 - 845 * k4 / 4104,
            u,
            p,
            t + Δt,
            submodel_tree,
        )
    k6 =
        Δt * _fc(
            x - 8 * k1 / 27 + 2 * k2 - 3544 * k3 / 2565 + 1859 * k4 / 4104 - 11 * k5 / 40,
            u,
            p,
            t + Δt / 2,
            submodel_tree,
        )
    @safeguard_off

    x_next_rk4 = x + 25 * k1 / 216 + 1408 * k3 / 2565 + 2197 * k4 / 4101 - k5 / 5
    x_next_rk5 =
        x + 16 * k1 / 135 + 6656 * k3 / 12825 + 28561 * k4 / 56430 - 9 * k5 / 50 +
        2 * k6 / 55

    truncation_error = max(abs.(x_next_rk4 - x_next_rk5)...)
    abs_tol = RKF45_REL_TOLERANCE * sqrt(sum(abs.(x_next_rk5) .^ 2))
    if truncation_error < abs_tol || truncation_error < RKF45_MIN_ABS_ERR
        return x_next_rk5, Δt # tolerance reached! Go with current RK5 estimate
    end

    # tolerance not yet reached. Decrease Δt and repeat RKF45 step
    Δt_new = 0.84 * (abs_tol / truncation_error)^(1 / 4) * Δt
    if Δt_new < Δt_MIN
        @warn "Reached a time step length of $Δt_new at time $t with truncation error $truncation_error. Your problem seems to be very stiff."
        return x_next_rk5, Δt # This step is not converging
    end
    return step_rkf45(Δt_new, fc, x, u, p, t, submodel_tree)
end

# wrapper for all continuous time integration methods
function step_ct(Δt, fc, x, args...; integrator = RK4)
    if x === nothing
        return nothing, Δt # state-less system
    end

    if integrator == RK4
        return step_rk4(Δt, fc, x, args...)
    elseif integrator == Euler
        return step_euler(Δt, fc, x, args...)
    elseif integrator == Heun
        return step_heun(Δt, fc, x, args...)
    elseif integrator == RKF45
        return step_rkf45(Δt, fc, x, args...)
    else
        @error "Integration method not supported."
    end
end

# steps a discrete time model
function step_dt(fd, x, u, p, t, submodel_tree, wd)
    fd_kwargs = length(submodel_tree) > 0 ? (models = submodel_tree,) : ()
    fd_kwargs = wd === nothing ? fd_kwargs : (fd_kwargs..., w = wd)
    return fd(x, u, p, t; fd_kwargs...)
end

export model_tree, print_model_tree
function model_tree(model)
    function print_model(
        model,
        depth;
        last = false,
        prev_groups_closed = [true for _ = 1:depth],
    )
        for i = 1:depth
            if prev_groups_closed[i]
                print(printSpace * printSpace)
            else
                print(printI * printSpace)
            end
        end
        !last ? print(printT) : print(printL)
        print(printLine)
        println("$(model.model_id) ($(model.type)): $(model.name) ")
    end

    @quiet working_copy = init_working_copy(model, structure_only = true)

    # print depth first / FIFO
    stack = Any[working_copy]
    depth_stack = Int[0]
    prev_groups_closed = []
    while !isempty(stack)
        node = pop!(stack)
        node_depth = pop!(depth_stack)
        last = isempty(stack) || depth_stack[1] != node_depth ? true : false

        print_model(node, node_depth, last = last, prev_groups_closed = prev_groups_closed)

        length(node.models) > 0 ? push!(prev_groups_closed, last) :
        (last && length(prev_groups_closed) > 0 ? pop!(prev_groups_closed) : nothing)
        for child in node.models
            pushfirst!(depth_stack, node_depth + 1)
            pushfirst!(stack, child)
        end
    end
    return nothing
end
const print_model_tree = model_tree
end # module SimpleSim

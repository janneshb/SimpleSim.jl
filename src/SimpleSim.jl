module SimpleSim

using Random
import Base.push!, Base.@inline, Base.gcd

global DEFAULT_Δt = 1 // 100 # default step size for CT systems, must be rational!
global DEFAULT_zero_crossing_precision = 1e-6
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
    yds0 =
        !structure_only && hasproperty(model, :yd) && model.yd !== nothing ?
        (
            length(sub_tree) > 0 ? [model.yd(xd0, ud0, model.p, t0; models = sub_tree)] :
            [model.yd(xd0, ud0, model.p, t0)]
        ) : nothing

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

    rng_dt =
        hasproperty(model, :wd) &&
        hasproperty(model, :wd_seed) &&
        model.wd_seed !== nothing ? BASE_RNG(model.wd_seed) : BASE_RNG(model_id)

    return (
        name = model_name,
        model_id = model_id,
        type = type,
        callable_ct! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_ct!(u, t, model, model_working_copy, Δt) : nothing,
        callable_dt! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_dt!(u, t, model, model_working_copy) : nothing,
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
        wds = !structure_only && hasproperty(model, :wd) ? [model.wd(ud0, model.p, t0, rng_dt)] : nothing,
        rng_dt = rng_dt,
        models = sub_tree,
    )
end

# adds an entry (tc, xc, yc) to the working copy of the model
function update_working_copy_ct!(model_working_copy, t, xc, yc)
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
function update_working_copy_dt!(model_working_copy, t, xd, yd, wd)
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
        wd !== nothing ? push!(model_working_copy.wds, eltype(model_working_copy.wds)(wd)) : nothing
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
    Δt_max = T,
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
    Δt_max = find_min_Δt(model, Δt_max)
    DEBUG && println("Using Δt = $Δt_max for continuous-time models.")

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
    ) # TODO: find better variable name for model_working_copy

    # simulate all systems that are due now
    t = t0
    simulation_is_running = true
    while simulation_is_running
        simulation_is_running, t =
            loop!(model_working_copy, model, uc, ud, t, Δt_max, T, integrator)
    end

    DEBUG && println("Simulation has terminated.")
    DEBUG && println("Processing data...")
    out = post_process(model_working_copy)
    DEBUG && println("Done!")
    return out
end

# the main simulation loop
function loop!(model_working_copy, model, uc, ud, t, Δt_max, T, integrator)
    t_next = t + Δt_max

    if t_next > T # end criterion
        return false, T
    end

    DEBUG &&
        DISPLAY_PROGRESS &&
        div(t_next, PROGRESS_SPACING * oneunit(Δt_max)) !=
        div(t_next - Δt_max, PROGRESS_SPACING * oneunit(Δt_max)) ?
    println("t = ", float(t_next)) : nothing

    (xc, yc, updated_state_ct) =
        model_working_copy.callable_ct!(uc(t), t_next, model_working_copy)

    (xd, yd, updated_state_dt) =
        model_working_copy.callable_dt!(ud(t), t_next, model_working_copy)

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
        (xc, yc, updated_state) =
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

function model_callable_ct!(uc, t, model, model_working_copy, Δt)
    # TODO: print warning when calling a CT system from within a DT system
    xc_next = model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end]
    yc_next = model_working_copy.ycs === nothing ? nothing : model_working_copy.ycs[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    @ct
    updated_state = false
    if due(model_working_copy, t)
        xc_next = step_ct(
            model_working_copy,
            model.fc,
            model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end],
            uc,
            model.p,
            model_working_copy.tcs[end],
            Δt,
            submodels,
        )
        t_next = model_working_copy.tcs[end] + Δt

        if hasproperty(model, :zc) &&
           model.zc !== nothing &&
           model.zc(xc_next, model.p, t_next) < -model_working_copy.zero_crossing_prec
            # Initialize bisection algorithm
            xc_lower = model_working_copy.xcs[end]
            t_lower = model_working_copy.tcs[end]
            t_upper = t_next

            # Run bisection until zero crossing precision is met
            while true
                try
                    Δt_bi = (t_upper - t_lower) / 2
                    xc_bi = step_ct(
                        model_working_copy,
                        model.fc,
                        xc_lower,
                        uc,
                        model.p,
                        t_lower,
                        Δt_bi,
                        submodels,
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
            Δt_post_zc = model_working_copy.tcs[end] + Δt - t_next
            update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next)

            # fill in the remaining time of Δt to avoid Rational overflow in future iterations
            xc_next = step_ct(
                model_working_copy,
                model.fc,
                xc_next,
                uc,
                model.p,
                t_next,
                Δt_post_zc,
                submodels,
            )
            t_next += Δt_post_zc
        end
        yc_next =
            length(submodels) > 0 ?
            model.yc(xc_next, uc, model.p, t_next; models = submodels) :
            model.yc(xc_next, uc, model.p, t_next)
        update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next)
        updated_state = true
    end
    @call_completed
    return (xc_next, yc_next, updated_state)
end

function model_callable_dt!(ud, t, model, model_working_copy)
    @dt
    xd_next = model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end]
    yd_next = model_working_copy.yds === nothing ? nothing : model_working_copy.yds[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    updated_state = false
    if due(model_working_copy, t)
        wd_next = hasproperty(model, :wd) ? model.wd(ud, model.p, t, model_working_copy.rng_dt) : nothing
        xd_next = step_dt(
            model_working_copy,
            model.fd,
            model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end],
            ud,
            model.p,
            t,
            submodels,
        )
        yd_next =
            length(submodels) > 0 ? model.yd(xd_next, ud, model.p, t; models = submodels) :
            model.yd(xd_next, ud, model.p, t)
        update_working_copy_dt!(model_working_copy, t, xd_next, yd_next, wd_next)
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

# Performs a random draw for this current model
# TODO: this doesn't work yet. Is there any way to make it even work this way?
export @draw
macro draw()
    quote
        quote
            local model_working_copy = $(esc($(esc(:this))))
        end
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
function find_min_Δt(model, Δt_prev)
    Δt = Δt_prev
    if hasproperty(model, :Δt) && model.Δt !== nothing
        Δt = gcd(Δt, check_rational(model.Δt))
    end

    if hasproperty(model, :models) && model.models !== nothing
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt)
        end
    end
    return gcd(Δt, check_rational(oneunit(Δt) * DEFAULT_Δt))
end


###########################
#       Integrators       #
###########################
export SimpleSimIntegrator, RK4, Euler, Heun
@enum SimpleSimIntegrator RK4 = 1 Euler = 2 Heun = 3

# Fourth-order Runge-Kutta method
# https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods
function step_rk4(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    fc_wrapper(fc, x, u, p, t, models) =
        length(models) > 0 ? fc(x, u, p, t; models = models) : fc(x, u, p, t)
    k1 = fc_wrapper(fc, x, u, p, t, submodel_tree)
    k2 = fc_wrapper(fc, x + k1 * Δt / 2, u, p, t + Δt / 2, submodel_tree)
    k3 = fc_wrapper(fc, x + k2 * Δt / 2, u, p, t + Δt / 2, submodel_tree)
    k4 = fc_wrapper(fc, x + k3 * Δt, u, p, t + Δt, submodel_tree)
    @safeguard_off
    return x + Δt * (k1 + 2 * k2 + 2 * k3 + k4) / 6
end

# explicit trapezoidal rule / Heun's method
# https://en.wikipedia.org/wiki/Heun%27s_method
function step_heun(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    fc_wrapper(fc, x, u, p, t, models) =
        length(models) > 0 ? fc(x, u, p, t; models = models) : fc(x, u, p, t)
    k1 = fc_wrapper(fc, x, u, p, t, submodel_tree)
    k2 = fc_wrapper(fc, x + k1 * Δt, u, p, t + Δt, submodel_tree)
    @safeguard_off
    return x + (k1 + k2) * Δt / 2
end

# classic (forward) Euler method
# https://en.wikipedia.org/wiki/Euler_method
function step_euler(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    k = length(submodel_tree) > 0 ? fc(x, u, p, t, models = submodel_tree) : fc(x, u, p, t)
    @safeguard_off
    return x + Δt * k
end

# wrapper for all continuous time integration methods
function step_ct(fc, x, args...; integrator = RK4)
    # TODO: implement support for other integrators, especially adaptive step

    if x === nothing
        return nothing # state-less system
    end

    if integrator == RK4
        return step_rk4(fc, x, args...)
    elseif integrator == Euler
        return step_euler(fc, x, args...)
    elseif integrator == Heun
        return step_heun(fc, x, args...)
    else
        @error "Integration method not supported."
    end
end

# steps a discrete time model
function step_dt(this, fd, x, u, p, t, submodel_tree)
    return length(submodel_tree) > 0 ? fd(x, u, p, t, models = submodel_tree) : fd(x, u, p, t)
end

export model_tree
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

end # module SimpleSim

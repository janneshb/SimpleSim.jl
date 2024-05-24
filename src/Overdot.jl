module Overdot

import Base.push!, Base.@inline, Base.gcd
using Random

global DEFAULT_Δt = 1//100 # default step size for CT systems, must be rational!
global DEBUG = true
global DISPLAY_PROGRESS = false

#########################
#       Utilities       #
#########################
@inline check_rational(x) = _check_rational(x)
@inline _check_rational(x::Rational{Int64}) = x
@inline _check_rational(x::Int) = x
@inline _check_rational(x::AbstractFloat) = begin; @error "Timesteps and durations should be given as `Rational` to avoid timing errors."; x; end
@inline _check_rational(x) = oneunit(x) * _check_rational(x.val) # assume it's a Unitful.jl Quantity
gcd(x, y) = oneunit(x) * Base.gcd(x.val, y.val) # for Unitful.jl Quantities

# @safeguard_on / @safeguard_off are macros for internal use only to protect models from being called
macro safeguard_on(); :(global MODEL_CALLS_DISABLED = true); end
macro safeguard_off(); :(global MODEL_CALLS_DISABLED = false); end

# @ct / @dt switches the context to CT/DT
# @context returns the current context
@enum OverdotContext Unknown=0 CT=1 DT=2
macro ct(); :(global CONTEXT = CT); end
macro dt(); :(global CONTEXT = DT); end
macro call_completed(); :(global CONTEXT = Unknown); end
macro context(); :(CONTEXT); end

# DO NOT CHANGE THESE GLOBAL VARIABLES
global MODEL_CALLS_DISABLED = false
global CONTEXT = Unknown

# initializes the "working copy" of the model that contains the states and outputs over the course of the simulation
function init_working_copy(model, t0, Δt, uc0, ud0; level = 0)
    # TODO: add support for StaticArrays and better type inference
    DEBUG && level == 0 ? println("Initializing models at t = ", float(t0)) : nothing
    DEBUG && level == 0 ? println("Top-level model is ", isCT(model) ? "CT." : (isDT(model) ? "DT." : "hybrid.")) : nothing

    sub_tree = (;)
    if hasproperty(model, :models)
        sub_tree = NamedTuple{keys(model.models)}(((init_working_copy(m_i, t0, Δt, nothing, nothing; level = level + 1) for m_i in model.models)...,))
    end

    xc0 = hasproperty(model, :xc0) ? model.xc0 : nothing
    uc0 = uc0 === nothing ? (hasproperty(model, :uc0) ? model.uc0 : nothing) : uc0
    ycs0 = hasproperty(model, :yc) ?
        (
            length(sub_tree) > 0 ? [model.yc(xc0, uc0, model.p, t0; models = sub_tree),] : [model.yc(xc0, uc0, model.p, t0),]
        ) : nothing

    xd0 = hasproperty(model, :xd0) ? model.xd0 : nothing
    ud0 = uc0 === nothing ? (hasproperty(model, :ud0) ? model.ud0 : nothing) : ud0
    yds0 = hasproperty(model, :yd) ?
        (
            length(sub_tree) > 0 ? [model.yd(xd0, ud0, model.p, t0; models = sub_tree),] : [model.yd(xd0, ud0, model.p, t0),]
        ) : nothing

    return (
        # callable = model_callable,
        callable_ct = (u, t, model_working_copy) -> model_callable_ct(u, t, model, model_working_copy, Δt),
        callable_dt = (u, t, model_working_copy) -> model_callable_dt(u, t, model, model_working_copy),
        Δt = hasproperty(model, :Δt) ? model.Δt : Δt,
        # the following store the latest state
        tcs = hasproperty(model, :yc) ? [t0,] : nothing,
        xcs = hasproperty(model, :fc) && xc0 !== nothing ? [xc0,] : nothing,
        ycs = ycs0,
        tds = hasproperty(model, :yd) ? [t0,] : nothing,
        xds = hasproperty(model, :fd) && xd0 !== nothing ? [xd0,] : nothing,
        yds = yds0,
        models = sub_tree,
    )
end

# adds an entry (t, xc, yc) to the working copy of the model
function update_working_copy_ct!(model_working_copy, t, xc, yc)
    push!(model_working_copy.tcs, t) # always store the time if the model was called
    xc !== nothing ? push!(model_working_copy.xcs, xc) : nothing
    yc !== nothing ? push!(model_working_copy.ycs, yc) : nothing
end

# adds an entry (t, xd, yd) to the working copy of the model
function update_working_copy_dt!(model_working_copy, t, xd, yd)
    push!(model_working_copy.tds, t) # always store the time if the model was called
    xd !== nothing ? push!(model_working_copy.xds, xd) : nothing
    yd !== nothing ? push!(model_working_copy.yds, yd) : nothing
end


####################
#       Core       #
####################
# entry hook for running a simuation
export simulate
function simulate(model; T,
        uc = (t) -> nothing,
        ud = (t) -> nothing,
        Δt_max = T,
        t0 = 0 // 1 * oneunit(T),
        seed = 1,
        integrator = RK4
    )

    # get supposed step size and end of simulation
    Δt_max = Δt_max === nothing ? oneunit(T) * DEFAULT_Δt : check_rational(Δt_max)
    T = check_rational(T)
    t0 = check_rational(t0)

    # find smallest time-step
    Δt_max = find_min_Δt(model, Δt_max)

    # initialize random number generator
    rng = Xoshiro(seed) # TODO: implement random draw hook (or macro?)

    # build callable structure to mimic the model tree
    model_working_copy = init_working_copy(model, t0, Δt_max, uc(t0), ud(t0)) # TODO: better variable name

    # simulate all systems that are due now
    t = t0
    simulation_is_running = true
    while simulation_is_running
        simulation_is_running, t = loop!(model_working_copy, model, uc, ud, t, Δt_max, T, integrator)
    end

    DEBUG && println("Simulation has terminated.")
    return model_working_copy
end

# the main simulation loop
function loop!(model_working_copy, model, uc, ud, t, Δt_max, T, integrator)
    t_next = t + Δt_max

    if t_next > T # end criterion
        return false, T
    end

    DEBUG && DISPLAY_PROGRESS ? println("t = ", float(t_next)) : nothing

    @ct
    if due(model_working_copy, t_next)
        xc_prev = model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end]
        uc_t_next = uc(t_next)
        sub_tree = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)
        xc_next = step_ct(model.fc, xc_prev, uc_t_next, model.p, t_next, Δt_max, model_working_copy.models, integrator = integrator)
        yc_next = length(sub_tree) > 0 ? model.yc(xc_next, uc_t_next, model.p, t_next, models = sub_tree) : model.yc(xc_next, uc_t_next, model.p, t_next)
        @call_completed
        update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next)
    end

    @dt
    if due(model_working_copy, t_next)
        xd_prev = model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end]
        ud_t_next = ud(t_next)
        sub_tree = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)
        xd_next = step_dt(model.fd, xd_prev, ud_t_next, model.p, t_next, model_working_copy.models)
        yd_next = length(sub_tree) > 0 ?  model.yd(xd_next, ud_t_next, model.p, t_next, models = model_working_copy.models) : model.yd(xd_next, ud_t_next, model.p, t_next)
        @call_completed
        update_working_copy_dt!(model_working_copy, t_next, xd_next, yd_next)
    end

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
        MODEL_CALLS_DISABLED && @error "@call! should not be called in the dynamics or step function. Use @out_ct and @out_dt to access the previous state instead (or @out in umambiguous cases)."

        model_to_call = $(esc(model))
        (xc, yc, updated_state) = model_to_call.callable_ct(
            $(esc(u)),
            $(esc(:t)),
            model_to_call,
        )
        if updated_state
            update_working_copy_ct!($(esc(model)), $(esc(:t)), xc, yc)
        end
        yc
    end
end

macro call_dt!(model, u)
    quote
        MODEL_CALLS_DISABLED && @error "@call! should not be called in the dynamics or step function. Use @out_ct and @out_dt to access the previous state instead (or @out in umambiguous cases)."

        model_to_call = $(esc(model))
        (xd, yd, updated_state) = model_to_call.callable_dt(
            $(esc(u)),
            $(esc(:t)),
            model_to_call
        )
        if updated_state
            update_working_copy_dt!($(esc(model)), $(esc(:t)), xd, yd)
        end
        yd
    end
end

function model_callable_ct(uc, t, model, model_working_copy, Δt)
    # TODO: print warning when calling a CT system from within a DT system
    @ct
    xc_next = model_working_copy.xcs[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    updated_state = false
    if due(model_working_copy, t)
        xc_next = step_ct(model.fc, model_working_copy.xcs[end], uc, model.p, t, Δt, submodels)
        updated_state = true
    end
    yc_next = length(submodels) > 0 ? model.yc(xc_next, uc, model.p, t; models = submodels) : model.yc(xc_next, uc, model.p, t)
    @call_completed
    return (xc_next, yc_next, updated_state)
end

function model_callable_dt(ud, t, model, model_working_copy)
    @dt
    xd_next = model_working_copy.xds[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    updated_state = false
    if due(model_working_copy, t)
        xd_next = step_dt(model.fd, model_working_copy.xds[end], ud, model.p, t, submodels)
        updated_state = true
    end
    yd_next = length(submodels) > 0 ? model.yd(xd_next, ud, model.p, t; models = submodels) : model.yd(xd_next, ud, model.p, t)
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
    return (hasproperty(model, :fc) && hasproperty(model, :yc)) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs !== nothing && model.xds === nothing) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs === nothing && model.xds === nothing) # last option is for state-less wrapper-models
end

function isDT(model)
    return (hasproperty(model, :fd) && hasproperty(model, :yc) && hasproperty(model, :Δt) && model.Δt !== nothing) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xds !== nothing && model.xcs === nothing)
end

function isHybrid(model)
    return (hasproperty(model, :fd) && hasproperty(model, :fc) && hasproperty(model, :yd) && hasproperty(model, :yc) && hasproperty(model, :Δt) && model.Δt !== nothing) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs !== nothing && model.xds !== nothing && hasproperty(model, :Δt) && model.Δt !== nothing)
end

function due(model, t)
    # TODO: this can be simplified
    context = @context
    if isCT(model) && context == CT
        return model.tcs[end] < t # CT models can always be updated if time has progressed
    end
    if isDT(model) && context == DT
        return model.tds[end] + model.Δt <= t
    end
    if isHybrid(model)
        if context == CT
            return model.tcs[end] < t # CT models can always be updated if time has progressed
        elseif context == DT
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

    if hasproperty(model, :models)
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt)
        end
    end
    return gcd(Δt, check_rational(oneunit(Δt) * DEFAULT_Δt))
end


###########################
#       Integrators       #
###########################
export OverdotIntegrator, RK4, Euler, Heun
@enum OverdotIntegrator RK4=1 Euler=2 Heun=3

# Fourth-order Runge-Kutta method
# https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods
function step_rk4(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    fc_wrapper(fc, x, u, p, t, models) = length(models) > 0 ? fc(x, u, p, t; models = models) : fc(x, u, p, t)
    k1 = fc_wrapper(fc, x,          u, p,    t,         submodel_tree)
    k2 = fc_wrapper(fc, x+k1*Δt/2,  u, p,    t + Δt/2,  submodel_tree)
    k3 = fc_wrapper(fc, x+k2*Δt/2,  u, p,    t + Δt/2,  submodel_tree)
    k4 = fc_wrapper(fc, x+k3*Δt,    u, p,    t + Δt,    submodel_tree)
    @safeguard_off
    return x + Δt*(k1 + 2*k2 + 2*k3 + k4)/6
end

# explicit trapezoidal rule / Heun's method
# https://en.wikipedia.org/wiki/Heun%27s_method
function step_heun(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    fc_wrapper(fc, x, u, p, t, models) = length(models) > 0 ? fc(x, u, p, t; models = models) : fc(x, u, p, t)
    k1 = fc_wrapper(fc, x,            u, p, t,      submodel_tree)
    k2 = fc_wrapper(fc, x + k1 * Δt,  u, p, t + Δt, submodel_tree)
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
    # TODO: implement support for other integrators, especially adaptive step and zero crossing detection

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
        @error "Integrator method not supported."
    end
end

# steps a discrete time model
function step_dt(fd, x, u, p, t, submodel_tree)
    return length(submodel_tree) > 0 ? fd(x, u, p, t, models = submodel_tree) : fd(x, u, p, t)
end

end # module Overdot

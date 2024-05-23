module Simulink

import Base.push!
using Random

global DEFAULT_Δt = 1//100 # default step size for CT systems, must be rational!
global DEBUG = true
global DISPLAY_PROGRESS = true
global MODEL_CALLS_DISABLED = false

# = UTILS = #
Base.@inline maybe_rationalize(x::AbstractFloat)::Rational{Int64}   = rationalize(x)
Base.@inline maybe_rationalize(x::Rational{Int64})::Rational{Int64} = x
Base.@inline maybe_rationalize(x)::Rational{Int64}                  = Rational{Int64}(x)

macro safeguard_on(); :(global MODEL_CALLS_DISABLED = true); end
macro safeguard_off(); :(global MODEL_CALLS_DISABLED = false); end

function find_min_Δt(model, Δt_prev)
    Δt = Δt_prev
    if hasproperty(model, :Δt)
        Δt = gcd(Δt, maybe_rationalize(model.Δt))
    end

    if hasproperty(model, :models)
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt)
        end
    end
    return gcd(Δt,maybe_rationalize(DEFAULT_Δt))
end

# = WORKING COPY MANIPULATORS = #
function init_working_copy(model, t0, Δt, uc0, ud0)
    # TODO: maybe we can find a way to omit the models kwarg when reaching the end of the tree
    sub_tree = (;)
    if hasproperty(model, :models)
        sub_tree = NamedTuple{keys(model.models)}(((init_working_copy(m_i, t0, Δt, nothing, nothing) for m_i in model.models)...,))
    end

    xc0 = hasproperty(model, :xc0) ? model.xc0 : nothing
    uc0 = uc0 === nothing ? (hasproperty(model, :uc0) ? model.uc0 : nothing) : uc0
    xd0 = hasproperty(model, :xd0) ? model.xd0 : nothing
    ud0 = uc0 === nothing ? (hasproperty(model, :ud0) ? model.ud0 : nothing) : ud0

    return (
        # callable = model_callable,
        callable_ct = (u, t, model_working_copy) -> model_callable_ct(u, t, model, model_working_copy, Δt),
        callable_dt = (u, t, model_working_copy) -> model_callable_dt(u, t, model, model_working_copy),
        Δt = hasproperty(model, :Δt) ? model.Δt : Δt,
        # the following store the latest state
        tcs = hasproperty(model, :yc) ? [t0,] : nothing,
        xcs = hasproperty(model, :fc) ? [xc0,] : nothing,
        ycs = hasproperty(model, :yc) ? [model.yc(xc0, uc0, model.p, t0; models = sub_tree),] : nothing,
        tds = hasproperty(model, :yd) ? [t0,] : nothing,
        xds = hasproperty(model, :fd) ? [xd0,] : nothing,
        yds = hasproperty(model, :yd) ? [model.yd(xd0, ud0, model.p, t0; models = sub_tree),] : nothing,
        models = sub_tree,
    )
end

function update_working_copy_ct!(model_working_copy, t, xc, yc)
    push!(model_working_copy.tcs, t) # always store the time if the model was called
    xc !== nothing ? push!(model_working_copy.xcs, xc) : nothing
    yc !== nothing ? push!(model_working_copy.ycs, yc) : nothing
end

function update_working_copy_dt!(model_working_copy, t, xd, yd)
    push!(model_working_copy.tds, t) # always store the time if the model was called
    xd !== nothing ? push!(model_working_copy.xds, xd) : nothing
    yd !== nothing ? push!(model_working_copy.yds, yd) : nothing
end

# = CORE = #
export simulate
function simulate(model; T,
        uc = (t) -> nothing,
        ud = (t) -> nothing,
        Δt_max = T,
        t0 = 0 // 1,
        seed = 1
    )

    # get supposed step size and end of simulation
    Δt_max = maybe_rationalize(Δt_max)
    T = maybe_rationalize(T)
    t0 = maybe_rationalize(t0)

    # find smallest time-step
    Δt_max = find_min_Δt(model, Δt_max)

    # initialize random number generator
    rng = Xoshiro(seed)

    # build callable structure to mimic the model tree
    model_working_copy = init_working_copy(model, t0, Δt_max, uc(t0), ud(t0)) # TODO: better variable name

    # simulate all systems that are due now
    t = t0
    simulation_is_running = true
    while simulation_is_running
        simulation_is_running, t = loop!(model_working_copy, model, uc, ud, t, Δt_max, T)
    end
    return model_working_copy
end

# = THE MAIN LOOP = #
function loop!(model_working_copy, model, uc, ud, t, Δt_max, T)
    t_next = t + Δt_max

    if t_next > T # end criterion
        return false, T
    end

    DEBUG || DISPLAY_PROGRESS ? println("t = ", float(t_next)) : nothing
    if due(model_working_copy, t_next)
        # evolve state
        uc_t_next = uc(t_next)
        ud_t_next = ud(t_next)

        if isCT(model) || isHybrid(model)
            xc_prev = model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end]
            xc_next = step_ct(model.fc, xc_prev, uc_t_next, model.p, t_next, Δt_max, model_working_copy.models)
            yc_next = model.yc(xc_next, uc_t_next, model.p, t_next, models = model_working_copy.models)
            update_working_copy_ct!(model_working_copy, t_next, xc_next, yc_next)
        elseif isDT(model) || isHybrid(model)
            xd_prev = model_working_copy.xds === nothing ? nothing : model_working_copy.xds[end]
            xd_next = step_dt(model.fd, xd_prev, ud_t_next, model.p, t_next, model_working_copy.models)
            yd_next = model.yd(xd_next, ud_t_next, model.p, t_next, models = model_working_copy.models)
            update_working_copy_dt!(model_working_copy, t_next, xd_next, yd_next)
        end
    end
    return true, t_next
end

# = CALLING A MDOEL FROM WITHIN THE SIM = #
export @call, @call_ct, @call_dt
macro call(model, u)
    # TODO: there is a way to simplify this
    quote
        model_to_call = $(esc(model))
        t = $(esc(:t))
        if isHybrid(model_to_call)
            @error "@call is ambiguous for hybrid systems. Please specify using @call_ct or @call_dt."
        elseif isCT(model_to_call)
            @call_ct model_to_call $(esc(u))
        elseif isDT(model_to_call)
            @call_dt model_to_call $(esc(u))
        end
    end
end

macro call_ct(model, u)
    quote
        if MODEL_CALLS_DISABLED
            @error "@call should not be called in the dynamics or step function. Use :xc and :xd to access the previous state instead."
        end

        model_to_call = $(esc(model))
        (xc, yc) = model_to_call.callable_ct(
            $(esc(u)),
            $(esc(:t)),
            model_to_call,
        )
        update_working_copy_ct!($(esc(model)), $(esc(:t)), xc, yc)
        yc
    end
end

macro call_dt(model, u)
    quote
        if MODEL_CALLS_DISABLED
            @error "@call should not be called in the dynamics or step function. Use :xc and :xd to access the previous state instead."
        end

        model_to_call = $(esc(model))
        (xd, yd) = model_to_call.callable_dt(
            $(esc(u)),
            $(esc(:t)),
            model_to_call
        )
        update_working_copy_dt!($(esc(model)), $(esc(:t)), xd, yd)
        yd
    end
end

function model_callable_ct(uc, t, model, model_working_copy, Δt)
    xc_next = model_working_copy.xcs[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    if due(model_working_copy, t)
        xc_next = step_ct(model.fc, model_working_copy.xcs[end], uc, model.p, t, Δt, submodels)
    end
    yc_next = model.yc(xc_next, uc, model.p, t; models = submodels)
    return (xc_next, yc_next)
end

function model_callable_dt(ud, t, mdoel, model_working_copy)
    xd_next = model_working_copy.xds[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    if due(model_working_copy, t)
        xd_next = step_dt(model.fd, model_working_copy.xds[end], ud, model.p, t, submodels)
    end
    yd_next = model.yd(xd_next, ud, mdoel.p, t; models = submodels)
    return (xd_next, yd_next)
end

# = MODEL ANALYSIS = #
function isCT(model)
    return (hasproperty(model, :fc) && !hasproperty(model, :fd)) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs !== nothing && model.xds === nothing) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs === nothing && model.xds === nothing) # last option is for state-less wrapper-models
end

function isDT(model)
    return (hasproperty(model, :fd) && !hasproperty(model, :fc)) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xds !== nothing && model.xcs === nothing)
end

function isHybrid(model)
    return (hasproperty(model, :fd) && hasproperty(model, :fc)) ||
            (hasproperty(model, :xcs) && hasproperty(model, :xds) && model.xcs !== nothing && model.xds !== nothing)
end

function due(model, t)
    if isCT(model)
        return model.tcs[end] < t # CT models can always be updated if time has progressed
    end
    if isDT(model)
        return model.tds[end] + model.Δt <= t
    end
    return false
end

# = STEP CT = #
function step_rk4(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    k1 = fc(x,          u, p,    t, models = submodel_tree)
    k2 = fc(x+k1*Δt/2,  u, p,    t + Δt/2, models = submodel_tree)
    k3 = fc(x+k2*Δt/2,  u, p,    t + Δt/2, models = submodel_tree)
    k4 = fc(x+k3*Δt,    u, p,    t + Δt, models = submodel_tree)
    @safeguard_off

    return x + Δt*(k1 + 2*k2 + 2*k3 + k4)/6
end

function step_euler(fc, x, u, p, t, Δt, submodel_tree)
    @safeguard_on
    k = fc(x, u, p, t, models = submodel_tree)
    @safeguard_off

    return x + Δt * k
end

function step_ct(fc, x, args...)
    if x === nothing
        return nothing # state-less system
    end

    # TODO: implement support for other integrators, especially adaptive step and zero crossing detection
    return step_rk4(fc, x, args...)
    #return step_euler(fc, x, args...)
end

# = STEP DT = #
function step_dt(fd, x, u, p, t, submodel_tree)
    return fd(x, u, p, t, models = submodel_tree)
end

end # module Simulink

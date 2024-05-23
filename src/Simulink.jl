module Simulink

import Base.push!
using Random

DEFAULT_Δt = 1//100 # default step size for CT systems

MODEL_CALLS_DISABLED = false
macro safeguard_on()
    quote
        MODEL_CALLS_DISABLED = true
    end
end

macro safeguard_off()
    quote
        MODEL_CALLS_DISABLED = false
    end
end

#=
if isHybrid(model)
    return simulate_hybrid_system(model; kwargs...)
elseif isCT(model)
    return simulate_ct_system(model; kwargs...)
elseif isDT(model)
    return simulate_dt_system(model; kwargs...)
else
    @error "Invalid system definition. At least one of the following properties has to be defined: (:fc, :fd)."
end
=#

# = UTILS = #
Base.@inline maybe_rationalize(x::AbstractFloat)::Rational{Int64}   = rationalize(x)
Base.@inline maybe_rationalize(x::Rational{Int64})::Rational{Int64} = x
Base.@inline maybe_rationalize(x)::Rational{Int64}                  = Rational{Int64}(x)

function find_min_Δt(model, Δt_prev)
    Δt = Δt_prev
    if hasproperty(model, :Δt)
        Δt = min(Δt, model.Δt)
    end

    if hasproperty(model, :models)
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt)
        end
    end
    return min(Δt, DEFAULT_Δt)
end

function init_working_copy(model, t0, Δt, uc0, ud0)
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
        callable = (u, t, model_working_copy) -> model_callable(u, t, model, model_working_copy, Δt),
        # the following store the latest state
        tcs = [t0,],
        xcs = hasproperty(model, :fc) ? [xc0,] : nothing,
        ycs = hasproperty(model, :yc) ? [model.yc(xc0, uc0, model.p, t0; models = sub_tree),] : nothing,
        tds = [t0,],
        xds = hasproperty(model, :fd) ? [xd0,] : nothing,
        yds = hasproperty(model, :yd) ? [model.yd(xd0, ud0, model.p, t0; models = sub_tree),] : nothing,
        models = sub_tree,
    )
end

function update_working_copy!(model_working_copy, t, xc, yc)
    push!(model_working_copy.tcs, t)

    if xc !== nothing
        push!(model_working_copy.xcs, xc)
    end

    if yc !== nothing
        push!(model_working_copy.ycs, yc)
    end
end

function model_callable(u, t, model, model_working_copy, Δt)
    # TODO: extend for DT
    # update the model (only once) and return the new output
    xc_next = model_working_copy.xcs[end]
    submodels = hasproperty(model_working_copy, :models) ? model_working_copy.models : (;)

    if due(model_working_copy, t)
        xc_next = step_ct(model.fc, model_working_copy.xcs[end], u, model.p, t, Δt, submodels)
    end
    yc_next = model.yc(xc_next, u, model.p, t; models = submodels)
    return (xc_next, yc_next)
end

# = CORE = #
export simulate, @call
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
    simulation_is_running, t = loop!(model_working_copy, model, uc, t0, Δt_max, T)
    while simulation_is_running
        simulation_is_running, t = loop!(model_working_copy, model, uc, t, Δt_max, T)
    end
    return model_working_copy
end

# = THE MAIN LOOP = #
function loop!(model_working_copy, model, u, t, Δt_max, T)
    # TODO: extend for DT
    t_next = t + Δt_max

    if t_next > T # end criterion
        return false, T
    end

    println(t_next)
    if due(model_working_copy, t_next)
        # evolve state
        u_t_next = u(t_next)
        x_old = model_working_copy.xcs === nothing ? nothing : model_working_copy.xcs[end]
        x_next = step_ct(model.fc, x_old, u_t_next, model.p, t_next, Δt_max, model_working_copy.models)

        # compute overall output
        y_next = model.yc(x_next, u_t_next, model.p, t_next, models = model_working_copy.models)

        update_working_copy!(model_working_copy, t_next, x_next, y_next)
    end
    return true, t_next
end

# = CALLING A MDOEL FROM WITHIN THE SIM = #
macro call(model, u)
    quote
        if MODEL_CALLS_DISABLED
            @error "@call should not be called in the dynamics or step function. Use :xc and :xd to access the previous state instead."
        end

        model_to_call = $(esc(model))
        (x, y) = model_to_call.callable(
            $(esc(u)),
            $(esc(:t)),
            model_to_call,
        )
        update_working_copy!($(esc(model)), $(esc(:t)), x, y)
        y
    end
end

# = MODEL ANALYSIS = #
function isCT(model)
    return (hasproperty(model, :fc) && !hasproperty(model, :fd)) || (model.xcs !== nothing && model.xds === nothing) || (model.xcs === nothing && model.xds === nothing) # last option is for state-less wrapper-models
end

function isDT(model)
    return (hasproperty(model, :fd) && !hasproperty(model, :fc)) || (model.xds !== nothing && model.xcs === nothing)
end

function isHybrid(model)
    return (hasproperty(model, :fd) && hasproperty(model, :fc)) || (model.xcs !== nothing && model.xds !== nothing)
end

function due(model, t)
    if isCT(model)
        return model.tcs[end] < t # CT models can always be updated if time has progressed
    end
    return false
end

#=
function eval_recursively(f::F, model) where {F}
    downstream = hasproperty(model, :models) ? (eval_recursively(f, m_i) for m_i in model.models) : (;)
    return f(model, downstream)
end

function eval_recursively(f::F, models::Tuple) where {F}
    return ((eval_recursively(f, m_i) for m_i in models)...,)
end

function eval_recursively(f::F, models::Vector) where {F}
    return [eval_recursively(f, m_i) for m_i in models]
end
=#

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
function step_dt(fd, x, u, p, t)
    return fd(x, u, p, t)
end

# = LOGGING = #
#=
struct ModelHistory{TC, XC, YC, TD, XD, YD, M}
    tc::TC
    xc::XC
    xc_dot::XC
    yc::YC
    td::TD
    xd::XD
    yd::YD
    models::M
end
=#

end # module Simulink

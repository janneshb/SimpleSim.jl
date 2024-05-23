module Simulink
import Base.push!

# = CORE = #
export simulate
function simulate(model; kwargs...)
    if isHybrid(model)
        return simulate_hybrid_system(model; kwargs...)
    elseif isCT(model)
        return simulate_ct_system(model; kwargs...)
    elseif isDT(model)
        return simulate_dt_system(model; kwargs...)
    else
        @error "Invalid system definition. At least one of the following properties has to be defined: (:fc, :fd)."
    end
end

function simulate_ct_system(model; x0, T, u, t0 = 0.0, Δt = 0.1)
    t = t0
    x = x0
    y0 = model.yc(x0, u(t0), model.p, t0)
    ts = TimeSeries([y0...], [t0], size(y0, 1))

    k = 0
    while t < T
        u_t = u(t)
        x = step_ct(model.fc, x, u_t, model.p, t, Δt)
        t += Δt
        y = model.yc(x, u_t, model.p, t)
        push!(ts, (y, t))
        k+=1
    end
    return (reshape(ts.X, ts.d, :), ts.t)
end

function simulate_dt_system(model; x0, T, Δt, u, t0 = 0.0)
    t = t0
    x = x0
    y0 = model.yd(x0, u(t0), model.p, t0)
    ts = TimeSeries([y0...], [t0], size(y0, 1))

    while t < T
        u_t = u(t)
        x = step_dt(model.fd, x, u_t, model.p, t)
        t += Δt
        y = model.yd(x, u_t, model.p, t)
        push!(ts, (y, t))
    end
    return (reshape(ts.X, ts.d, :), ts.t)
end

function simulate_hybrid_system(model; T, x0, Δt, u, x0_DT = x0, x0_CT = x0, Δt_DT = Δt, Δt_CT = Δt, t0 = 0.0)
    # TODO
end

# = MODEL ANALYSIS = #
function isCT(model)
    return hasproperty(model, :fc) && !hasproperty(model, :fd)
end

function isDT(model)
    return hasproperty(model, :fd) && !hasproperty(model, :fc)
end

function isHybrid(model)
    return hasproperty(model, :fd) && hasproperty(model, :fc)
end

function due(model, t)
    if isCT(model)
        return true # CT models can always be updated
    end
end

# = STEP CT = #
function step_rk4(fc, x, u, p, t, Δt)
    k1 = fc(x,          u, p,    t)
    k2 = fc(x+k1*Δt/2,  u, p,    t + Δt/2)
    k3 = fc(x+k2*Δt/2,  u, p,    t + Δt/2)
    k4 = fc(x+k3*Δt,    u, p,    t + Δt)

    return x + Δt*(k1 + 2*k2 + 2*k3 + k4)/6
end

function step_euler(fc, x, u, p, t, Δt)
    return x + Δt * fc(x, u, p, t)
end

function step_ct(args...)
    # TODO: implement support for other integrators, especially adaptive step and zero crossing detection
    return step_rk4(args...)
end

# = STEP DT = #
function step_dt(fd, x, u, p, t)
    return fd(x, u, p, t)
end

# = LOGGING = #
struct TimeSeries
    X
    t
    d
end

function push!(ts::TimeSeries, pair)
    append!(ts.X, pair[1]...)
    push!(ts.t, pair[2])
end


end # module Simulink

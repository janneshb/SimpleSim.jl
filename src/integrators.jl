# steps a discrete-time model
function step_dt(fd, x, u, p, t, submodel_tree, wd)
    fd_kwargs = length(submodel_tree) > 0 ? (models = submodel_tree,) : ()
    fd_kwargs = wd === nothing ? fd_kwargs : (fd_kwargs..., w = wd)
    return fd(x, u, p, t; fd_kwargs...)
end

# steps a continuous-time model, wrapper for all continuous time integration methods
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

## Euler
# Classic (forward) Euler method
# https://en.wikipedia.org/wiki/Euler_method
function step_euler(Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    k = length(submodel_tree) > 0 ? fc(x, u, p, t, models = submodel_tree) : fc(x, u, p, t)
    @safeguard_off
    return x + Δt * k, Δt
end

## Heun
# Explicit trapezoidal rule / Heun's method
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

## RK4
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

## RKF45
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

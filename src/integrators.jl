# Inline helper: calls fc with or without the `models` keyword based on a Val{Bool} type
# parameter. Using Val dispatch instead of a runtime branch eliminates the per-step `_fc`
# closure allocation and lets Julia dead-code-eliminate the unused path.
@inline _call_fc(fc, x, u, p, t, st, ::Val{true})  = fc(x, u, p, t; models = st)
@inline _call_fc(fc, x, u, p, t, ::Any, ::Val{false}) = fc(x, u, p, t)

# steps a discrete-time model
function step_dt(fd, x, u, p, t, submodel_tree, wd)
    isnothing(x) && return nothing # state-less system

    fd_kwargs = length(submodel_tree) > 0 ? (models = submodel_tree,) : ()
    fd_kwargs = wd === nothing ? fd_kwargs : (fd_kwargs..., w = wd)
    return fd(x, u, p, t; fd_kwargs...)
end

# Internal hot-path dispatcher: Val{integrator} × Val{has_submodels} → fully specialised method.
# Called directly from model_callable_ct! so the compiler sees concrete types at every call site.
_step_ct(::Val{RK4},   hsm::Val, Δt, fc, x, u, p, t, st) = step_rk4(hsm, Δt, fc, x, u, p, t, st)
_step_ct(::Val{Euler}, hsm::Val, Δt, fc, x, u, p, t, st) = step_euler(hsm, Δt, fc, x, u, p, t, st)
_step_ct(::Val{Heun},  hsm::Val, Δt, fc, x, u, p, t, st) = step_heun(hsm, Δt, fc, x, u, p, t, st)
_step_ct(::Val{RKF45}, hsm::Val, Δt, fc, x, u, p, t, st) = step_rkf45(hsm, Δt, fc, x, u, p, t, st)

# Public wrapper — preserves the original args... signature for backward compatibility.
# The early return handles state-less models before args are inspected.
function step_ct(Δt, fc, x, args...; integrator::SimpleSimIntegrator = RK4)
    isnothing(x) && return nothing, Δt # state-less system
    u, p, t, submodel_tree = args[1], args[2], args[3], args[4]
    _step_ct(Val(integrator), Val(length(submodel_tree) > 0), Δt, fc, x, u, p, t, submodel_tree)
end

## Euler
# Classic (forward) Euler method
# https://en.wikipedia.org/wiki/Euler_method
function step_euler(has_submodels::Val, Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    k = _call_fc(fc, x, u, p, t, submodel_tree, has_submodels)
    @safeguard_off
    return x + Δt * k, Δt
end

## Heun
# Explicit trapezoidal rule / Heun's method
# https://en.wikipedia.org/wiki/Heun%27s_method
function step_heun(has_submodels::Val, Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    k1 = _call_fc(fc, x, u, p, t, submodel_tree, has_submodels)
    k2 = _call_fc(fc, x + k1 * Δt, u, p, t + Δt, submodel_tree, has_submodels)
    @safeguard_off
    return x + (k1 + k2) * Δt / 2, Δt
end

## RK4
# Fourth-order Runge-Kutta method
# https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods
function step_rk4(has_submodels::Val, Δt, fc, x, u, p, t, submodel_tree)
    @safeguard_on
    k1 = _call_fc(fc, x, u, p, t, submodel_tree, has_submodels)
    k2 = _call_fc(fc, x + k1 * Δt / 2, u, p, t + Δt / 2, submodel_tree, has_submodels)
    k3 = _call_fc(fc, x + k2 * Δt / 2, u, p, t + Δt / 2, submodel_tree, has_submodels)
    k4 = _call_fc(fc, x + k3 * Δt, u, p, t + Δt, submodel_tree, has_submodels)
    @safeguard_off
    return x + Δt * (k1 + 2 * k2 + 2 * k3 + k4) / 6, Δt
end

## RKF45
# Runge-Kutta-Fehlberg method / RKF45
# https://en.wikipedia.org/wiki/Runge–Kutta–Fehlberg_method
# https://maths.cnam.fr/IMG/pdf/RungeKuttaFehlbergProof.pdf
function step_rkf45(has_submodels::Val, Δt, fc, x, u, p, t, submodel_tree)
    Δt = float(Δt)
    @safeguard_on
    k1 = Δt * _call_fc(fc, x, u, p, t, submodel_tree, has_submodels)
    k2 = Δt * _call_fc(fc, x + k1 / 4, u, p, t + Δt / 4, submodel_tree, has_submodels)
    k3 = Δt * _call_fc(fc, x + 3 * k1 / 32 + 9 * k2 / 32, u, p, t + 3 * Δt / 8, submodel_tree, has_submodels)
    k4 = Δt * _call_fc(
        fc,
        x + 1932 * k1 / 2197 - 7200 * k2 / 2197 + 7296 * k3 / 2197,
        u, p, t + 12 * Δt / 13,
        submodel_tree, has_submodels,
    )
    k5 = Δt * _call_fc(
        fc,
        x + 439 * k1 / 216 - 8 * k2 + 3680 * k3 / 513 - 845 * k4 / 4104,
        u, p, t + Δt,
        submodel_tree, has_submodels,
    )
    k6 = Δt * _call_fc(
        fc,
        x - 8 * k1 / 27 + 2 * k2 - 3544 * k3 / 2565 + 1859 * k4 / 4104 - 11 * k5 / 40,
        u, p, t + Δt / 2,
        submodel_tree, has_submodels,
    )
    @safeguard_off

    x_next_rk4 = x + 25 * k1 / 216 + 1408 * k3 / 2565 + 2197 * k4 / 4104 - k5 / 5
    x_next_rk5 =
        x + 16 * k1 / 135 + 6656 * k3 / 12825 + 28561 * k4 / 56430 - 9 * k5 / 50 +
        2 * k6 / 55

    truncation_error = max(abs.((x_next_rk4 - x_next_rk5) ./ oneunit.(x_next_rk4))...)
    abs_tol = RKF45_REL_TOL * sqrt(sum(abs.(x_next_rk5 ./ oneunit.(x_next_rk4)) .^ 2))
    if truncation_error < abs_tol || truncation_error < RKF45_ABS_TOL
        return x_next_rk5, Δt # tolerance reached! Go with current RK5 estimate
    end

    # tolerance not yet reached. Decrease Δt and repeat RKF45 step
    Δt_new = 0.84 * (abs_tol / truncation_error)^(1 / 4) * Δt
    if Δt_new < ΔT_MIN
        !SILENT &&
            @warn "Reached a time step length of $Δt_new at time $t with truncation error $truncation_error. Your problem seems to be very stiff."
        return x_next_rk5, Δt # This step is not converging
    end
    return step_rkf45(has_submodels, Δt_new, fc, x, u, p, t, submodel_tree)
end

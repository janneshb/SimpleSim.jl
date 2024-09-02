# Standalone Simulations

## Continuous-Time Simulations

### Dynamics Model

```math
\dot{x}(t) = f(x(t), u(t), p, t)
```

```julia
function fc_my_model(x, u, p, t)
    my_x_derivative = # ...
    return my_x_derivative
end
```

### Measurement Model

```math
y(t) = g(x(t), u(t), p, t)
```

```julia
function yc_my_model(x, u, p, t)
    my_output = # ...
    return my_output
end
```

### Model Creation

### Running the Simulation

## Discrete-Time Simulations

### Dynamics Model

```math
x_{k+1} = f(x_k, u_k, p, t)
```

```julia
function fd_my_model(x, u, p, t)
    my_next_x = # ...
    return my_next_x
end
```

### Measurement Model

```math
y_k = g(x_k, u_k, p, t)
```

```julia
function yd_my_model(x, u, p, t)
    my_output = # ...
    return my_output
end
```

### Model Creation

### Running the Simulation

```julia
out = simulate(my_model, T = T_end)
```

__Mandatory Keyword Arguments:__

* `T` total time of the simulation

__Optional Keyword Arguments:__

* `t0` initial time, defaults to `0//1`
* `xd0` initial state, defaults to `nothing`. Overwrites initial state given in model.
* `x0` for convenience, if given it replaces `xd0`. `xd0` and `x0` must not be given at the same time.
* `ud` input function  `(t) -> some_input`, if none is given, the input will be `nothing` for all times.

__Supported Keywords with no Effect for DT Simulations:__

* `uc` input only used for continuous-time models
* `xc0` initial state only used for continuous-time models
* `integator` no integrator is used for discrete-time simulations
* `Δt_max` only relevant for integrators and therefore irrelevant for discrete-time models

## Mixing Continuous-Time and Discrete-Time (Hybrid Simulations)

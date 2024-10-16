# Discrete-Time Models

Discrete-time models are defined by a "step" function, that returns the next state, based on the current state of the system and a measurement function.

```math
x_{k+1} = f(x_k, u_k, p, t)\\
y_k = g(x_k, u_k, p, t)
```

Both $f$ and $g$ are assumed to be explicit, algebraic functions. Implicit definitions of $x_{k+1}$ and $y_k$ are not supported.

## Dynamics Model

The discrete-time dynamics

```math
x_{k+1} = f(x_k, u_k, p, t)
```

are modeled in `SimpleSim.jl` using a simple Julia function that returns $x_{k+1}$ as an `AbstractVector`.

```julia
function fd_my_model(x, u, p, t)
    my_next_x = # ...
    return my_next_x
end
```

Note, that while working with integer time-steps $k$, the functions $f$ and $g$ still accept the actual time $t$ as an input. This is more practical for most applications. If you want to work with integer time steps $k$ instead, make sure to use a sampling time of `1 // 1` and convert the time `t` to an integer inside your functions $f$ and $g$.

## Measurement Model

The measurement model

```math
y_k = g(x_k, u_k, p, t)
```

is also given by a simple Julia function

```julia
function gd_my_model(x, u, p, t)
    my_output = # ...
    return my_output
end
```

(Pretty straighforward, right?)

## Model Creation

Similar to continuous-time models, `SimpleSim.jl` supports all types of models that have named fields. So you can either define your own struct for each type of model, or simply use a `NamedTuple`.

```julia
my_dt_model = (
    p = nothing,
    fd = fd_my_model,
    gd = gd_my_model,
    Δt = Δt_my_model,
    xd0 = my_initial_state,
    ud0 = my_initial_input,
)
```

__Mandatory__ fields for discrete-time models:

* `p`, set this to `nothing` if no parameters are needed
* `fd`, pass your dynamics function returning the next state
* `gd`, pass your measurement function
* `Δt`, the desired sampling time of the discrete-time model, use `1 // 1` for integer time steps $k$.

__Optional__ fields for discrete-time models:

* `xd0`, the initial state of the system, `nothing` by default. Can be overriden by initial state directly passed to the [`simulate`](@ref) function.
* `ud0`, the initial input of the system, `nothing` by default.

## Hybrid Models

Models can have both continuous-time and discrete-time dynamics. These kind of models are considered `HybridModels` by `SimpleSim.jl` and they work very similar to continuous-time or discrete-time models.

Note, that for hybrid models, the mandatory fields for __both__ continuous-time and discrete-time models must be given.

See [`@call_ct!`](@ref)/[`@call_dt!`](@ref), [`@out_ct`](@ref)/[`@out_dt`](@ref), and [`@state_ct`](@ref)/[`@state_dt`](@ref) for some comments about how do avoid ambiguity when working with hybrid models.

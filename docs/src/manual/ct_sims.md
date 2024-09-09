# Continuous-Time Models

Every continuous-time model consists of a dynamics model $f$ and a measurement model $g$.

```math
\dot{x}(t) = f(x(t), u(t), p, t)
y(t) = g(x(t), u(t), p, t)
```

The dynamics model is given by a first-order ordinary differential equation. The measurement model is given by a simple algebraic function.

## Dynamics Model

The `SimpleSim.jl` equivalent of the first-order ordinary differential equation

```math
\dot{x}(t) = f(x(t), u(t), p, t)
```

is to define a function that returns the current derivative

```julia
function fc_my_model(x, u, p, t)
    my_x_derivative = # ...
    return my_x_derivative
end
```

Implicit differential equations $0 = F(\dot{x}, x, u, p, t)$ are not supported.

## Measurement Model

The measurement model

```math
y(t) = g(x(t), u(t), p, t)
```

is also implemented as a simple Julia function that returns the current output $y(t)$ given the current state $x(t)$, input $u(t)$ and time $t$, as well as the parameters $p$.

```julia
function yc_my_model(x, u, p, t)
    my_output = # ...
    return my_output
end
```

## Model Creation

Every `SimpleSim.jl` model has to be a data structure with named fields. So, you can use a custom struct to define your models or simply use a `NamedTuple`. Structs may have some advantages when it comes to debugging your code, however, for simple examples, `NamedTuple` are more than sufficient.

```julia
my_ct_model = (
    p = nothing,
    fc = fc_my_model,
    yc = yc_my_model,
    xc0 = my_initial_state,
    uc0 = my_initial_input,
)
```

__Mandatory__ fields for continuous-time models:

* `p`, set to `nothing` if no parameters are needed
* `fc`, pass your dynamics function, returning the right-hand side of the ODE
* `yc`, pass your measurement function

__Optional__ fields for continuous-time models:

* `xc0`, the initial state of the system, `nothing` by default. Can be overriden by initial state directly passed to the [`simulate`](@ref) function
* `uc0`, the initial input of the system

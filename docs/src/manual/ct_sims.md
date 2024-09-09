### Dynamics Model

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
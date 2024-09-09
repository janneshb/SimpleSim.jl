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

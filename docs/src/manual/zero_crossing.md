# Zero-Crossing Detection

The zero-crossing detection feature allows for building models that have discontinuous dynamics. An example for a dynamical system where this feature is used would be a ball bouncing up and down on a hard surface.

## Theory

The goal of a zero-crossing detector is to solve the following equation

```math
0 = z(x(t), p, t)
```
for $x(t)$ and $t$.

In simulation, this is done by checking for a change of sign in $z$.

If
```math
z(x(t), p, t) < 0\\
z(x(t + T), p, t + T) > 0,
```
then a zero-crossing has happened. In that case, a bisection algorithm is applied to find $T^*$, such that
```math
\lvert z(x(t + T^*), p, t + T^*)\rvert < \varepsilon
```
where $\varepsilon$ is a small tolerance.

## Implementation

`SimpleSim.jl` supports the optional fields `zc` and `zc_exec` for continuous-time models that are used to implement the zero-crossing detection feature.

* `zc` tells us when the zero-crossing is happening
* `zc_exec` tells us what to do, once a zero-crossing is found

### `zc` function

The function passed to `zc` takes the current state, the model parameters and the current time as an input and returns a `Number`. This number represents the quantity that is critical for a zero-crossing.

```julia
function zc_my_model(x, p, t)
    my_zc_indicator = # ...
    return my_zc_indicator
end
```

If the number returned by `zc` changes its sign, the simulation engine will try to figure out when exactly the zero-crossing has happened.
In order to do so, a bisection algorithm is applied to find the right simulation step size, so that the next simulation step occurs right at the time of the zero-crossing.

### `zc_exec` function

This function tells the simulation engine what to do, once it has figured out when a zero-crossing is happening (as defined by `zc`).

The `zc_exec` works similar to a discrete-time state update. When a zero-crossing is happening, it is called exactly once and should return a new, post-zero-crossing state of the system.

```julia
function zc_exec_my_model(x, u, p, t)
    my_new_state = # ...
    return my_new_state
end
```

The new state should be constructed in a way that resolves the zero-crossing. Otherwise, the simulation can get stuck in a loop.

In summary, a model with zero-crossing detection could look something like this.

```julia
my_ct_model = (
    p = nothing,
    fc = fc_my_model,
    gc = gc_my_model,
    zc = zc_my_model,
    zc_exec = zc_exec_my_model,
    xc0 = my_initial_state,
    uc0 = my_initial_input,
)
```

Since varying the simulation step size is not allowed for discrete-time systems,
zero-crossing detection is only supported for continuous-time systems.

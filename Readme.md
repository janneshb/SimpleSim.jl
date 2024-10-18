# SimpleSim.jl

[![](https://img.shields.io/badge/docs-online-blue.svg)](https://janneshb.github.io/SimpleSim.jl/dev/)
[![JuliaTest](https://github.com/janneshb/SimpleSim.jl/workflows/CI/badge.svg)](https://github.com/janneshb/SimpleSim.jl/actions)
[![Codecov](https://img.shields.io/codecov/c/github/janneshb/SimpleSim.jl)](https://codecov.io/gh/janneshb/SimpleSim.jl)

<b>SimpleSim.jl</b> is a light-weight simulation package for dynamical systems simulation, controller synthesis and testing and robotics.

Run `import Pkg; Pkg.add("SimpleSim")` from within your Julia environment to install `SimpleSim.jl`.

## Short Overview

The main point of interaction with `SimpleSim.jl` is the `simulate` function. As a first argument, it expects to be passed _some_ object that provides named fields that supply hooks for various functionalities.

A simple example of a dynamical system model accepted by `SimpleSim.jl` would be
```julia
my_model = (
    p = nothing,
    fc = dynamics_function,
    gc = measurement_function,
)
```
where we pass `nothing` as the parameters of the model (i.e. we don't need any parameters right now) and two functions `dynamics_function` and `measurement_function` that we have defined elsewhere.

These two functions model the dynamics of the model using the following approach for continuous-time dynamical systems
```math
\dot{x}(t) = f(x(t), u(t), p, t)\\
y(t) = g(x(t), u(t), p, t)
```
or in Julia

```julia
dynamics_function = (x, u, p, t) -> ...
measurement_function = (x, u, p, t) -> ...
```

Similarly, `SimpleSim.jl` supports discrete-time systems
```math
x_{k+1} = f(x_k, u_k, p, t)\\
y_k = g(x_k, u_k, p, t)
```
which are modeled as
```julia
my_dt_model = (
    p = nothing,
    fd = dt_dynamics_function,
    gd = dt_measurement_function,
    Δt = 1 // 10,
)
```

Running a simulation is as easy as calling `simulate` with your model and a total simulation time `T`.

```julia
data = simulate(my_model, T = 10 // 1)
```

## Examples

Multiple demos in the `examples/` provide a rough but incomplete overview of what `SimpleSim.jl` can do.

Some examples are described in detail in the [official documentation](https://janneshb.github.io/SimpleSim.jl/). In the future more complex examples and tutorials will be added there.

## Credit

A similar simulation architecture was proposed by [@tuckermcclure](https://www.github.com/tuckermcclure) in [overdot-sandbox](https://github.com/tuckermcclure/overdot-sandbox).

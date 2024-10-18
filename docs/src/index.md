# Introduction

`SimpleSim.jl` is a minimalist Julia framework for modular dynamical system simulation.

For installation, run `import Pkg; Pkg.add("SimpleSim.jl")` from within your Julia environment.

## Philosophy

This software project aims at removing a lot of the overhead that a lot of the existing simulation frameworks out there have.
`SimpleSim.jl` does not export any types. The interface almost solely consists of the function `simulate` and a agreed-upon model structure.
The light interface results in most design decisions left up to the user.

At the same time `SimpleSim.jl` does not compromise on functionality and offers a feature-rich simulation framework.

## Short overview

The main point of interaction with the `SimpleSim.jl` framework is the `simulate` function. As a first argument it expects to be passed _some_ object that provides hooks with certain names for various functionalities.

### Continuous-Time Systems

A simple example of a dynamical system model accepted by `SimpleSim.jl` would be

```julia
my_model = (
    fc = dynamics_function,
    gc = measurement_function,
)
```
where we pass two functions `dynamics_function` and `measurement_function` that we defined elsewhere.

These two functions follow the typical dynamical systems approach for continuous-time systems

```math
\dot{x}(t) = f(x(t), u(t), p, t)\\
y(t) = g(x(t), u(t), p, t)
```

or in Julia

```julia
dynamics_function = (x, u, p t) -> ...
measurement_function = (x, u, p t) -> ...
```

If `my_model` has no field named `p`, `SimpleSim.jl` will pass `nothing` to `fc` and `gc`.

### Discrete-Time Systems

Similarly for a discrete-time system we write

```julia
next_state_function = (x, u, p, t) -> ...
dt_measurement_function = (x, u, p, t) -> ...

my_dt_model = (
    fd = next_state_function,
    gd = dt_measurement_function,
    Δt = 1 // 10,
)
```

modeling the system

```math
x_{k+1} = f(x_k, u_k, p, t)\\
y_k = g(x_k, u_k, p, t)
```

### Running Simulations

Simulating a model is done by calling the `simulate` function

```julia
out = simulate(my_model, T = 10 // 1)
```

add the keyword argument `xc0 =` or `xd0 =` to set the initial state of your continuous-time or discrete-time model, respectively.

### Modularity

`SimpleSim.jl` takes a hierarchical approach to more complex, modular systems. That means any model can have any number of submodels. To define submodels, a `Vector`, `Tuple` or `NamedTuple` of models is passed to the `models` keywords on creation of the model.

```julia
submodel_1 = (
    p = ...,
    fc = ...,
    gc = ...,
)

submodel_2 = ...

parent_model = (
    p = ...,
    fc = fc_parent,
    gc = gc_parent,
    models = (
        model_1 = submodel_1,
        model_2 = submodel_2,
    )
)
```

Now, `parent_model` has two submodels. Note, that submodels are not updated automatically. They have to be _called_ by their parent model. Only the top-level model passed to `simulate` is actively updated by `SimpleSim.jl`.

For calling a submodel, use the `@call!` macro from within a `gc` function and add the input you want to give the submodel.

```julia
function gc_parent(x, u, p, t; models)
    u_1 = ...
    y_submodel_1 = @call! models.model_1 u_1

    u_2 = ...
    y_submodel_2 = @call! models.model_2 u_2

    return ...
end
```

Calls can only be made from within a `gc` function. Not from within an `fc` function. To obtain the current output of a submodel without updating it, use the `@out` macro.

```julia
function fc_parent(x, u, p, t; models)
    y_1 = @out models.model_1
    # ...
end
```

Discrete-time systems work in the same way. However, `SimpleSim.jl` makes sure that discrete-time models are only updated according to their update frequency.

## Citing

If you used `SimpleSim.jl` in research and you are preparing a publication, please use the following BiBTeX entry:

```
@software{SimpleSim,
    author = {H{\"u}hnerbein, Jannes},
    title = {{S}imple{S}im.jl: {A} minimalist {J}ulia package for modular dynamical systems simulation},
    url = {https://github.com/janneshb/SimpleSim.jl},
    version = {0.1.4},
    year = {2024},
    month = {04},
}
```

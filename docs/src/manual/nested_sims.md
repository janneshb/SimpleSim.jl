# Nested Models

One of `SimpleSim.jl`'s most powerful feature is the ability to structure models in hierarchies. In other words, every model in a simulation can have an arbitrary number of submodels.

This enables you to use `SimpleSim.jl` in a similar way to how you would draw a control block diagram.

For example, the closed-loop system consisting of a controller and a plant could be implemented as three systems:

* the controller
* the plant
* a feedback system

The controller and the plant would then be subsystems of the "feedback sytem". The feedback system takes care of passing the current output of the plant to the controller and calling the plant with the current control input.

## Creating Submodels

`SimpleSim.jl` accepts three types of collections to serve as a list of submodels:
* `Vector`
* `Tuple`
* `NamedTuple`

Given three submodels `model_1`, `model_2` and `model_3` created as described in the chapters about continuous-time and discrete-time models, the creation of the `submodels` structure is shown below.

As a `Vector`:
```julia
my_submodels = [model_1, model_2, model_3]
```

As a `Tuple`:
```julia
my_submodels = (model_1, model_2, model_3)
```

As a `NamedTuple`:
```julia
my_submodels = (
    m_1 = model_1,
    m_2 = model_2,
    m_3 = model_3
)
```

Any of the above can be passed to the parent model as follows.
```julia
my_ct_model = (
    p = nothing,
    fc = fc_my_model,
    yc = yc_my_model,
    xc0 = my_initial_state,
    uc0 = my_initial_input,
    models = my_submodels,
)
```

## Calling Submodels

Only the top-level passed to the `simulate` function is actively called by `SimpleSim.jl`. Submodels must be called by their respective parent model.

This is done using the `@call!` macro and can only be done from within the `yc` and `yd` functions. Calls from inside `fc` or `fd` are not allowed for technical reasons.

An example of how to call a submodel is given below.
```julia
function yc_my_model(x, u, p, t; models)
    my_submodel_input = # ...

    # if `models` is a Vector or Tuple
    y = @call! models[1] my_submodel_input

    # if `models` is a NamedTuple
    y = @call! models.m_1 my_submodel_input
end
```

After calling (and therefore updating) a submodel you can do whatever you need to do with its output.
Note that `SimpleSim.jl` takes care of timing issues. Submodels are only updated if they are due. This is of course only relevant for discrete-time systems.

If you need to access the output of a submodel from inside a `fc` function, use the `@out` macro. It returns the current output of a submodel without updating it.
```julia
function fc_my_model(x, u, p, t; models)
    # if `models` is a Vector or Tuple
    y = @out models[1]

    # if `models` is a NamedTuple
    y = @out models.m_1
end
```

Several illustrative examples of nested simulations are given in the examples section.

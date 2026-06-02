# Simulation Output

If you run a simulation

```julia
data = simulate(my_model, T = T)
```

the object `data` will contain all relevant simulation output as a `NamedTuple`.

## Fields

The output object mimics the structure of the respective model and has the following fields.

__Model information:__

* `model_id` the integer ID assigned to the model
* `Δt` the sampling time of the model, or `nothing` for pure continuous-time models

__Continuous-time output:__

* `tcs` vector of time values at which the continuous-time state was recorded
* `xcs` state trajectory produced by `fc`. `nothing` if the model has no continuous-time dynamics.
* `ycs` output trajectory produced by `gc`. `nothing` if the model has no continuous-time output function.

__Discrete-time output:__

* `tds` vector of time values at which the discrete-time state was recorded
* `xds` state trajectory produced by `fd`. `nothing` if the model has no discrete-time dynamics.
* `yds` output trajectory produced by `gd`. `nothing` if the model has no discrete-time output function.
* `wds` random draw trajectory produced by `wd`. `nothing` if the model has no random draw function.

__Submodels:__

* `models` contains the outputs of all submodels, mirroring the structure of the `models` field in the original model definition.

## Time-Series Format

If a state or output is an `AbstractVector` of numbers (the common case), `SimpleSim.jl` stacks all time steps into a matrix after the simulation finishes. Each row corresponds to one time step and each column corresponds to one state or output dimension.

```julia
data.tcs          # Vector of length N
data.xcs          # Matrix of size N × nx
data.ycs          # Matrix of size N × ny
```

If the state or output is a scalar or a non-numeric type it is returned as a plain vector with one entry per time step.

## Accessing Submodel Output

Output of submodels can be accessed via the `models` field. For example, if the top-level model has a continuous-time submodel called `my_submodel`, then its output can be accessed via

```julia
data.models.my_submodel.ycs
```

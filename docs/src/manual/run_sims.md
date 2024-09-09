# Running Simulations

```julia
out = simulate(my_model, T = T_end)
```

__Mandatory__ Keyword Arguments:

* `T` total time of the simulation

__Optional__ Keyword Arguments:

* `t0` initial time, defaults to `0//1`
* `xd0` initial state, defaults to `nothing`. Overwrites initial state given in model.
* `ud` input function  `(t) -> some_input`, if none is given, the input will be `nothing` for all times.

__Supported__ Keywords with no Effect for DT Simulations:

* `uc` input only used for continuous-time models
* `xc0` initial state only used for continuous-time models
* `integator` no integrator is used for discrete-time simulations
* `Δt_max` only relevant for integrators and therefore irrelevant for discrete-time models

## TODO: add some more info
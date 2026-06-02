# Running Simulations

```julia
out = simulate(my_model, T = T_end)
```

__Mandatory__ Keyword Arguments:

* `T` total time of the simulation

__Optional__ Keyword Arguments:

* `t0` initial time, defaults to `0//1`
* `uc` input function `(t) -> u` for continuous-time models, defaults to `(t) -> nothing`
* `ud` input function `(t) -> u` for discrete-time models, defaults to `(t) -> nothing`
* `xc0` initial state for continuous-time models, defaults to `nothing`. Overwrites the initial state given in the model definition.
* `xd0` initial state for discrete-time models, defaults to `nothing`. Overwrites the initial state given in the model definition.
* `Δt_max` maximum step size used for continuous-time integration, defaults to `1//100`
* `integrator` integration method for continuous-time models, defaults to `RK4`. See the [integrators overview](@ref) for available methods.
* `options` a `NamedTuple` of additional simulation options, see below.

## Options

Additional options can be passed as a `NamedTuple` to the `options` keyword argument.

```julia
out = simulate(my_model,
    T = 20 // 1,
    options = (
        silent = true,
        base_rng = Xoshiro,
    )
)
```

__Available__ options:

* `Δt_default` replaces the default maximum step size for continuous-time integration. Should be rational. Defaults to `1//100`.
* `Δt_min` minimum step size for continuous-time integration. Especially relevant for adaptive step size integrators. Defaults to `1//1_000_000`.
* `zero_crossing_tol` absolute tolerance for zero-crossing time detection. Defaults to `1e-5`.
* `RKF45_rel_tol` relative tolerance between truncation error and 5th order estimate for the `RKF45` integrator. Defaults to `1e-6`.
* `RKF45_abs_tol` absolute tolerance for the truncation error in the `RKF45` integrator. Defaults to `1e-7`.
* `display_progress` set to `false` to suppress progress output in the terminal. Defaults to `true`.
* `progress_spacing` time between progress updates in the terminal. Defaults to `1//1`.
* `debug` set to `true` to print additional debug information. Defaults to `false`.
* `silent` set to `true` to suppress all output including warnings and errors. Defaults to `false`.
* `base_rng` random number generator used for random draw functions. Defaults to `MersenneTwister`.
* `out_stream` IO stream used for console output. Defaults to `stdout`.

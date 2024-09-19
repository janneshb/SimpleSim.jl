# Continuous-Time Intgration Methods -- An Overview

### Available Solving Methods

* Forward Euler `Euler`
* Heun's Method `Heun`
* Forth-Order Runge-Kutta Method `RK4`
* Runge-Kutta-Fehlberg-Method `RKF45`

The list is ordered by fastest to slowest and at the same time by least to most precise.

### Usage

Supported integration methods are exported by `SimpleSim.jl` as part of the enum `SimpleSimIntegrator`.

```julia
@enum SimpleSimIntegrator RK4 = 1 Euler = 2 Heun = 3 RKF45 = 4
```

To choose an integration method for simulation, use the `integrator` keyword argument when running a simulation.

```julia
out = simulate(my_model, T = T_end, integrator = Heun)
```

Fourth-order Runge-Kutta (`RK4`) is used by default.

### Step Size Computation

The step size $\Delta t$ stays constant over the whole duration of the simulation. It is computed as the minimum of `Δt_max`, a keyword argument of `simulate`, and the greatest common divisor of `Δt_max` and all `Δt` values given for all models in the simulation.

All continuous-time models that are part of the same simulation are updated at the same frequency determined by the "fastest" model in the simulation.
This sampling time is determined by computing the greatest common rational divisor of all sampling times in the simulation.
Apart performance concerns it is always better to update continuous-time models more frequently.

__Example:__

Assume you have set up a model that should be updated at least every twelfth of a second.

```julia
my_model = (
    # ...
    Δt = 1 // 12,
)

out = simulate(my_model, T = T_end, Δt_max = 1 // 20)
```

The fixed step size integrators will now be called with `Δt = 1 // 60`, which is the greatest common divisor of $\frac{1}{12}$ and $\frac{1}{20}$.

By default, `Δt_max` is set to `1 // 100` which is more than sufficient for most applications.

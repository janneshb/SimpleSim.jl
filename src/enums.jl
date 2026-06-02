@enum ModelType TypeUnknown = 0 TypeCT = 1 TypeDT = 2 TypeHybrid = 3
@enum SimulationContext ContextUnknown = 0 ContextCT = 1 ContextDT = 2

export SimpleSimIntegrator, RK4, Euler, Heun, RKF45
"""
    @enum SimpleSimIntegrator

Numerical integration methods for continuous-time simulations. Pass to the `integrator` keyword argument of [`simulate`](@ref).

- `RK4`: 4th-order Runge-Kutta (default). Good balance of accuracy and speed for most problems.
- `Euler`: Forward Euler. Fastest but lowest accuracy; use only for simple problems or prototyping.
- `Heun`: Heun's method (explicit trapezoidal, 2nd-order). More accurate than Euler at similar cost.
- `RKF45`: Runge-Kutta-Fehlberg with adaptive step size. Most accurate; best for stiff or sensitive systems.

See the [integrators overview](@ref) for a detailed comparison.
"""
@enum SimpleSimIntegrator RK4 = 1 Euler = 2 Heun = 3 RKF45 = 4

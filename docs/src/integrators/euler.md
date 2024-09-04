# Forward Euler Integration / `Euler`

## Usage

The desired integration method used for continuous-time dynamics is passed to the `simulate` function as a keyword argument.

```julia
using SimpleSim

# my_model = ...

out = simulate(my_model, T = T_end, integrator = Euler)
```

## Mathematical Background

The state $x^+$ estimating the true state at time $t+\Delta t$ is determined by simple integration of the current derivative $\dot{x}(t)$ computed using the dynamics function $f(x(t), u(t), p, t)$.

```math
x^+ = x + \Delta t \cdot f(x, u(t), p, t)
```

This method is also referred to as _forward Euler method_ and is the most basic explicit method for solving initial value problems.

You can read more about this topic on [Wikipedia](https://en.wikipedia.org/wiki/Euler_method) or any text book on the topic, many of which are available on the internet.


## Performance

For each iteration, the dynamics function $f$ is only called once and the state update itself is computationally very inexpensive.

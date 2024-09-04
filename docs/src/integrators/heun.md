# Heun's Method / Explicit Trapezoidal Integration / `Heun`

## Usage

The desired integration method used for continuous-time dynamics is passed to the `simulate` function as a keyword argument.

```julia
using SimpleSim

# my_model = ...

out = simulate(my_model, T = T_end, integrator = Heun)
```

## Mathematical Background

Heun's method, also known as _improved Euler's method_ or _explicit trapezoidal rule_ is a two-stage method.

First, an intermediate estimate of the next state $\tilde{x}^+$ is computed using Euler's method

```math
\tilde{x}^+ = x + \Delta t\cdot f(x, u(t), p, t)
```

The final estimate $x^+$ is then computed using a weighted average of the current derivative and the expected derivative at the next Euler step.

```math
x^+ = x + \frac{\Delta t}{2} (f(x, u(t), p, t) + f(\tilde{x}^+, u(t + \Delta t), p, t + \Delta t))
```

You can read more about this topic on [Wikipedia](https://en.wikipedia.org/wiki/Heun%27s_method).

## Performance

The two-step process used in Heun's method results in two calls of the dynamics function $f$ being made. Therefore, the computational effort is about twice as large compared to Euler's method. However, in most cases, Heun's method is still very fast.

Compared to Euler's method, the accumulation of errors has a significantly lower effect when using Heun's method yielding much better results.

# 4th Order Runge-Kutta Method / `RK4`

## Usage

The desired integration method used for continuous-time dynamics is passed to the `simulate` function as a keyword argument.

```julia
using SimpleSim

# my_model = ...

out = simulate(my_model, T = T_end, integrator = RK4)
```

## Mathematical Background

As the name suggests, this method is a four-step algorithm.

First, the derivative function $f$ is evaluated at four different points.

```math
k_1 = f(x, u(t), p, t)
```
```math
k_2 = f(x + \frac{\Delta t}{2} k_1, u(t + \frac{\Delta t}{2}), p, t + \frac{\Delta t}{2})
```
```math
k_3 = f(x + \frac{\Delta t}{2} k_2, u(t + \frac{\Delta t}{2}), p, t + \frac{\Delta t}{2})
```
```math
k_4 = f(x + \Delta t\cdot k_3, u(t + \Delta t), p, t + \Delta t)
```

The RK4 estimate of the state at time $t + \Delta t$ is then given by the weighted average.
```math
x^+ = x + \frac{\Delta t}{6} (k_1 + 2 k_2 + 2 k_3 + k_4)
```

## Performance

The fourth-order Runge-Kutta method requires four calls of the dynamics function and is therefore the slowest out of all fixed step-size methods provided by `SimpleSim.jl`.

In most cases, however, the evaluation of $f$ is fast enought so that `RK4` can be used as the standard integration method.

The advantages in terms of precision compared to first and second order methods are imense and generally RK4 is sufficiently exact.

In rare cases, however, an adaptive step-size variation of RK4 should be used. See the chapter about Runge-Kutta-Fehlberg for more information.

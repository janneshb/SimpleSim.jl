# Runge-Kutta-Fehlberg Method / `RKF45`

## Usage

The desired integration method used for continuous-time dynamics is passed to the `simulate` function as a keyword argument.

```julia
using SimpleSim

# my_model = ...

out = simulate(my_model, T = T_end, integrator = RKF45)
```

## Mathematical Background


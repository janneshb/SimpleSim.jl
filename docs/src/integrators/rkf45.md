# Runge-Kutta-Fehlberg Method / `RKF45`

## Usage

The desired integration method used for continuous-time dynamics is passed to the `simulate` function as a keyword argument.

```julia
using SimpleSim

# my_model = ...

out = simulate(my_model, T = T_end, integrator = RKF45)
```

## Mathematical Background

The Runge-Kutta-Fehlberg method, also known as Fehlberg's method or simply RKF45, is an adaptive step size solver for ordinary differential equations.
The core idea of the method is to adjust the current step size by looking at the difference between the estimates using the 4th and 5th order Runge-Kutta methods.

First, the 4th and 5th order Runge-Kutta estimates are computed. We denote these as $x^+_\text{RK4}$ and $x^+_\text{RK5}$, respectively. Given the coefficients $k_1$ through $k_6$, the two estimates can be computed as follows.

$$
x^+_\text{RK4} = x + \Delta t(\frac{25}{216} k_1 + \frac{1408}{2565}k_3 + \frac{2197}{4101}k_4 - \frac{1}{5}k_5)
$$

$$
x^+_\text{RK5} = x + \Delta t(\frac{16}{135} k_1 + \frac{6656}{12825}k_3 + \frac{28561}{56430}k_4 - \frac{9}{50}k_5 + \frac{2}{55}k_6)
$$

Where the coefficients $k_i$ are computed as

$$
k_1 = f(x, u(t), p, t)
$$
$$
k_2 = f(x + \frac{\Delta t}{4} k_1, u(t + \frac{\Delta t}{4}), p, t + \frac{\Delta t}{4})
$$
$$
k_3 = f(x + \frac{3\Delta t}{32} k_1 + \frac{9\Delta t}{32}k_2, u(t + \frac{3\Delta t}{8}), p, t + \frac{3\Delta t}{8})
$$
$$
k_4 = f(x + \frac{1932\Delta t}{2197}k_1 - \frac{7200\Delta t}{2197}k_2 + \frac{7296\Delta t}{2197} k_3, u(t + \frac{12\Delta t}{13}), p, t+ \frac{12\Delta t}{13})
$$
$$
k_5 = f(x + \frac{439\Delta t}{216}k_1 - 8\Delta t k_2 + \frac{3680\Delta t}{513}k_3 - \frac{845 \Delta t}{4104}k_4, u(t + \Delta t), p, t + \Delta t)
$$
$$
k_6 = f(x - \frac{8\Delta t}{27} k_1 + 2\Delta tk_2 - \frac{3544\Delta t}{2565} + \frac{1859\Delta t}{4104}k_4 - \frac{11\Delta t}{40}k_5, u(t + \frac{\Delta t}{2}), p, t + \frac{\Delta t}{2})
$$

After computing both estimates, the optimal adaptive step size $\Delta t_\text{opt}$ can be computed using the following formula,
$$
\Delta t_\text{opt} = \Delta t\cdot \bigg(\frac{\varepsilon}{2\lvert x^+_\text{RK4} - x^+_\text{RK5} \rvert}\bigg)^{0.25},
$$
where $\varepsilon$ denotes a desired tolerance.

`SimpleSim.jl` uses the following approximation
$$
\Delta t_\text{opt} = 0.84\cdot \bigg(\frac{\varepsilon_\text{abs}}{\lVert x^+_\text{RK4} - x^+_\text{RK5} \rVert_\infty}\bigg)^{0.25},
$$
where the absolute tolerance is computed as
$$
\varepsilon_\text{abs} = \varepsilon_\text{rel}\cdot \lVert x^+_\text{RK5}\rVert_2
$$
and the relative tolerance is a constant simulation option called `RKF45_REL_TOL`.

You can read more about this on [Wikipedia](https://en.wikipedia.org/wiki/Runge–Kutta–Fehlberg_method), on [this great website](https://ece.uwaterloo.ca/~dwharder/NumericalAnalysis/14IVPs/rkf45/complete.html) by the University of Waterloo or in [this very helpful excerpt](https://maths.cnam.fr/IMG/pdf/RungeKuttaFehlbergProof.pdf) from a text book on numerical methods by John Mathews and Kurtis Fink.

## Performance

For obivious reasons, Runge-Kutta-Fehlberg is the slowest method supported by `SimpleSim.jl`.
The system dynamics function is called at least six times and for stiff problems the adaptive step size can get very small causing the simulation to become very slow.

However, for certain classes of problems, adaptive step size methods are absolutely necessary. Especially system's with sensitive dependence on initial conditions, i. e. chaotic systems, can be solved much faster and with higher precision using adaptive step size methods. The only alternative would be using a fixed step size method with a very small step size. This, however, would be computationally more expensive in a lot of cases.

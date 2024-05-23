using Simulink
using StaticArrays

# dynamic rule for the damped pendulum
fd_pendulum(x, u, p, t) = p.A * x

# measurement model
yd_pendulum(x, u, p, t) = x

pendulum_discrete = (
    p = (
        A = [
            0.978941   0.0492763;
            -0.837274  0.964158
        ],
    ),
    fd = fd_pendulum,
    yd = yd_pendulum,
)


T = 30.0
Δt = 0.05
x0 = [
    30.0 *π/180.0,   #*s/s,
    0.0              #*1/s
]
u(t) = 0.0

Y, t = simulate(pendulum_discrete, T = T, Δt = Δt, x0 = x0, u = u)

using Plots
plot(t, Y[1, :], seriestype = :steppost)

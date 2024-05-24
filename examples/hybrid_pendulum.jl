using Overdot
using StaticArrays

# dynamic rule for the damped pendulum
fc_pendulum(x, u, p, t) = SVector(x[2], -p.λ*x[2] - p.ω2*sin(x[1]))
fd_pendulum(x, u, p, t) = p.A * x

# measurement model
yc_pendulum(x, u, p, t) = x
yd_pendulum(x, u, p, t) = x

x0 = [
    30.0 *π/180.0,   #*s/s,
    0.0              #*1/s
]

pendulum_hybrid = (
    p = (
        g = 9.81,
        L = 0.5,
        ω2 = 9.81/0.5, # equals g/L
        λ = 0.3,
        A = [
            0.978941   0.0492763;
            -0.837274  0.964158
        ],
    ),
    Δt = 0.05,
    xc0 = x0,
    xd0 = x0,
    fc = fc_pendulum,
    fd = fd_pendulum,
    yc = yc_pendulum,
    yd = yd_pendulum,
)


T = 30.0

u(t) = 0.0

history = simulate(pendulum_hybrid, T = T, uc = u, ud = u)

using Plots
plot(history.tcs, getindex.(history.ycs, 1))

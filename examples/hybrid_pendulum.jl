using SimpleSim

"""
    Hybrid Pendulum

    This file simulates a model that has both CT and DT dynamics.
    Hence, the CT nonlinear pendulum can be directly compared
    to the DT linearization.
"""

show_plots = false

# dynamic rule for the damped pendulum
fc_pendulum(x, u, p, t) = [x[2], -p.λ * x[2] - p.ω2 * sin(x[1])]
fd_pendulum(x, u, p, t) = p.A * x

# measurement model
gc_pendulum(x, u, p, t) = x
gd_pendulum(x, u, p, t) = x

x0 = [
    30.0 * π / 180.0,   #*s/s,
    0.0,              #*1/s
]

pendulum_hybrid = (
    p = (
        g = 9.81,
        L = 0.5,
        ω2 = 9.81 / 0.5, # equals g/L
        λ = 0.3,
        A = [
            0.978941 0.0492763
            -0.837274 0.964158
        ],
    ),
    Δt = 5 // 100,
    xc0 = x0,
    xd0 = x0,
    fc = fc_pendulum,
    fd = fd_pendulum,
    gc = gc_pendulum,
    gd = gd_pendulum,
)


T = 30 // 1

u(t) = 0.0

history = simulate(pendulum_hybrid, T = T, uc = u, ud = u)

if show_plots
    using Plots
    plotlyjs()
    plot(history.tcs, history.ycs[:, 1])
    plot!(history.tds, history.yds[:, 1])
end

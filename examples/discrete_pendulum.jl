using SimpleSim

show_plots = false

# dynamic rule for the damped pendulum
fd_pendulum(x, u, p, t) = p.A * x

# measurement model
yd_pendulum(x, u, p, t) = x

x0 = [
    30.0 * π / 180.0,   #*s/s,
    0.0,              #*1/s
]
Δt = 5 // 100
pendulum_discrete = (
    p = (A = [
        0.978941 0.0492763
        -0.837274 0.964158
    ],),
    xd0 = x0,
    Δt = Δt,
    fd = fd_pendulum,
    yd = yd_pendulum,
)


T = 10 // 1
u(t) = 0.0
history = simulate(pendulum_discrete, T = T, ud = u)

if show_plots
    using Plots
    plotlyjs()
    plot(history.tds, history.yds[:, 1], seriestype = :steppost)
end

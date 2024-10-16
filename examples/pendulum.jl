using SimpleSim

show_plots = false

# dynamic rule for the damped pendulum
fc_pendulum(x, u, p, t) = [x[2], -p.λ * x[2] - p.ω2 * sin(x[1])]

# measurement model
gc_pendulum(x, u, p, t) = x

x0 = [
    30.0 * π / 180.0,   #*s/s,
    0.0,              #*1/s
]
pendulum = (
    p = (
        g = 9.81,
        L = 0.5,
        ω2 = 9.81 / 0.5, # equals g/L
        λ = 0.3,
    ),
    xc0 = x0,
    fc = fc_pendulum,
    gc = gc_pendulum,
)


T = 30 // 1
u(t) = 0.0

history = simulate(pendulum, T = T, uc = u)

if show_plots
    using Plots
    plotlyjs()
    plot(history.tcs, history.ycs[:, 1])
end

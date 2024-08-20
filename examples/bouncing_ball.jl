using SimpleSim
using StaticArrays

show_plots = true

stairs(x) = -round(x)

fc_bouncing_ball(x, u, p, t) =
    SVector(x[3], x[4], -1.0 * p.c * x[3]^2, -1.0 * p.c * x[4]^2 - p.g)

yc_bouncing_ball(x, u, p, t) = SVector(x[1], x[2])

zc_bouncing_ball(x, p, t) = x[2] - stairs(x[1]) # function that quantifies "zero-crossing happened!", must be scalar

zc_exec_bouncing_ball(x, u, p, t) = SVector(x[1], x[2], x[3], -p.ε * x[4])

x0 = [0, 3.0, 3.0, 0]

bouncing_ball = (
    p = (g = 9.81, c = 0.0, ε = 0.8),
    xc0 = x0,
    fc = fc_bouncing_ball,
    yc = yc_bouncing_ball,
    zc = zc_bouncing_ball,
    zc_exec = zc_exec_bouncing_ball,
)

T = 10 // 1

history = simulate(bouncing_ball, T = T)

if show_plots
    using Plots
    plotlyjs()
    p1 = plot(
        history.xcs[:, 1],
        history.xcs[:, 2],
        aspect_ratio = :equal,
        xlabel = "x",
        ylabel = "y",
    )
    p1 = plot!(p1, history.xcs[:, 1], stairs.(history.xcs[:, 1]))
    display(p1)

    p2 = plot(
        history.tcs[1:end-1],
        history.tcs[2:end] .- history.tcs[1:end-1],
        seriestype = :steppost,
        xlabel = "t",
        ylabel = "Δt",
    )
    display(p2)
end

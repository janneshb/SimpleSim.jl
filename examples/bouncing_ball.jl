using SimpleSim

"""
    Bouncing Ball

    This file simulates a ball bouncing down a flight of stairs.
    This is mainly to demonstrate the zero-crossing detection capabilities of SimpleSim.jl.
"""

show_plots = true

stairs(x) = -round(x)

fc_bouncing_ball(x, u, p, t) = [x[3], x[4], -1.0 * p.c * x[3]^2, -1.0 * p.c * x[4]^2 - p.g]

yc_bouncing_ball(x, u, p, t) = [x[1], x[2]]

zc_bouncing_ball(x, p, t) = x[2] - stairs(x[1]) # function that quantifies "zero-crossing happened!", must be scalar

zc_exec_bouncing_ball(x, u, p, t) = [x[1], x[2], x[3], -p.ε * x[4]]

x0 = [0, 3.0, 3.0, 0]

bouncing_ball = (
    p = (g = 9.81, c = 0.0, ε = 0.8),
    xc0 = x0,
    fc = fc_bouncing_ball,
    yc = yc_bouncing_ball,
    zc = zc_bouncing_ball,
    zc_exec = zc_exec_bouncing_ball,
)

T = 11 // 1

history = simulate(bouncing_ball, T = T, integrator = RK4, options = (silent = true,))

include("utils/zoh.jl")
tcs_zoh, xcs_zoh = @zoh history.tcs history.xcs 1 // 20

if show_plots
    using Plots
    plotlyjs()

    T_animation = float(T)
    fps = Int(round(length(tcs_zoh) / T_animation))

    animation = @animate for (i, t_i) in enumerate(tcs_zoh)
        p1 = plot(layout = (1, 1))
        plot!(p1,
            xcs_zoh[1:i, 1],
            xcs_zoh[1:i, 2],
            aspect_ratio = :equal,
            xlabel = "x",
            ylabel = "y",
        )

        plot!(p1[1], xcs_zoh[:, 1], stairs.(xcs_zoh[:, 1]))

        scatter!(
            p1[1],
            [xcs_zoh[i, 1]],
            [xcs_zoh[i, 2]],
            markersize = 7,
            label = "",
            framestyle = :none,
            size = (500, 500),
            dpi = 10,
            color = "#000000",
        ) # bob

        xlims!(p1[1], 1.1*minimum(xcs_zoh[:, 1]), 1.1*maximum(xcs_zoh[:, 1]))
        ylims!(p1[1], 1.1*minimum(xcs_zoh[:, 2]), 1.1*maximum(xcs_zoh[:, 2]))
    end
    ani = gif(animation, "examples/plots/bouncing_ball.gif", fps = fps)
    display(ani)

    p2 = plot(
        history.tcs[1:end-1],
        history.tcs[2:end] .- history.tcs[1:end-1],
        seriestype = :steppost,
        xlabel = "t",
        ylabel = "Δt",
    )
    display(p2)
end

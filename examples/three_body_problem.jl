using SimpleSim
using LinearAlgebra

show_plots = true

function fc_three_bodies(x, u, p, t)
    r1 = x[1:2]
    r2 = x[3:4]
    r3 = x[5:6]
    r_1_dd =
        -p.G * p.m2 * (r1 - r2) / (norm(r1 - r2)^2) -
        p.G * p.m3 * (r1 - r3) / (norm(r1 - r3)^2)
    r_2_dd =
        -p.G * p.m3 * (r2 - r3) / (norm(r2 - r3)^2) -
        p.G * p.m1 * (r2 - r1) / (norm(r2 - r1)^2)
    r_3_dd =
        -p.G * p.m1 * (r3 - r2) / (norm(r3 - r2)^2) -
        p.G * p.m2 * (r3 - r2) / (norm(r3 - r2)^2)

    return vcat(x[7:end], r_1_dd, r_2_dd, r_3_dd)
end

function yc_three_bodies(x, u, p, t)
    return x[1:6]
end

r0 = 1e7
x0 = vcat(
    [
        r0 * cosd(-30),
        r0 * sind(-30),
        r0 * cosd(90),
        r0 * sind(90),
        r0 * cosd(210),
        r0 * sind(210),
    ],
    [
        0.0,
        0.0,
        3000000.0,
        -3000000.0,
        0.0,
        0.0,
    ]
)

mass_scaling = 0.6
three_bodies = (
    p = (G = 6.67430e-11, m1 = mass_scaling*5e24, m2 = mass_scaling*5e24, m3 = mass_scaling*5e24),
    xc0 = x0,
    fc = fc_three_bodies,
    yc = yc_three_bodies,
)

T = 15 // 1
out = simulate(three_bodies, T = T, integrator = RKF45)

r1_traj = out.xcs[:, 1:2]
r2_traj = out.xcs[:, 3:4]
r3_traj = out.xcs[:, 5:6]


if show_plots
    using Plots
    # plotlyjs()
    p1 = plot(
        r1_traj[:, 1],
        r1_traj[:, 2],
        aspect_ratio = :equal,
        xlabel = "x",
        ylabel = "y",
    )
    plot!(r2_traj[:, 1], r2_traj[:, 2])
    plot!(r3_traj[:, 1], r3_traj[:, 2])
    display(p1)

    p2 = plot(
        out.tcs[1:end-1],
        out.tcs[2:end] .- out.tcs[1:end-1],
        seriestype = :steppost,
        xlabel = "t",
        ylabel = "Δt",
    )
    display(p2)

    p2 = plot(out.tcs, r1_traj[:, 1], name = "r1")
    plot!(out.tcs, r2_traj[:, 1], name = "r2")
    plot!(out.tcs, r3_traj[:, 1], name = "r3")
    display(p2)

    # Logo generation
    julia_blue = "#4063D8"
    julia_green = "#389826"
    julia_red = "#CB3C33"
    julia_purple = "#9558B2"

    strokewidth = 3
    markersize = 50

    p_logo = plot(
        size=(500,500),
        aspect_ratio = :equal,
        background_color = :transparent,
        axis=([], false),
        legend=false,
    )

    plot!(p_logo, r1_traj[:, 1], r1_traj[:, 2], color="#eee", linewidth=strokewidth)
    plot!(p_logo, r2_traj[:, 1], r2_traj[:, 2], color="#eee", linewidth=strokewidth)
    plot!(p_logo, r3_traj[:, 1], r3_traj[:, 2], color="#eee", linewidth=strokewidth)

    scatter!(p_logo, [r1_traj[1, 1]], [r1_traj[1, 2]],
        markerstrokecolor="#eee",
        markercolor=julia_green,
        markersize=markersize,
    )
    scatter!(p_logo, [r2_traj[1, 1]], [r2_traj[1, 2]],
        markerstrokecolor="#eee",
        markercolor=julia_red,
        markersize=markersize,
    )
    scatter!(p_logo, [r3_traj[1, 1]], [r3_traj[1, 2]],
        markerstrokecolor="#eee",
        markercolor=julia_purple,
        markersize=markersize,
    )

    display(p_logo)
end

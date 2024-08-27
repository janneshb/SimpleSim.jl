using SimpleSim
using LinearAlgebra

show_plots = false

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
        r0 * cosd(0),
        r0 * sind(0),
        r0 * cosd(120),
        r0 * sind(120),
        r0 * cosd(240),
        r0 * sind(240),
    ],
    zeros(6),
)

three_bodies = (
    p = (G = 6.67430e-11, m1 = 5e24, m2 = 5e24, m3 = 5e24),
    xc0 = x0,
    fc = fc_three_bodies,
    yc = yc_three_bodies,
)

T = 10 // 1
out = simulate(three_bodies, T = T, integrator = RKF45)

r1_traj = out.xcs[:, 1:2]
r2_traj = out.xcs[:, 3:4]
r3_traj = out.xcs[:, 5:6]


if show_plots
    using Plots
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
end

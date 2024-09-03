using SimpleSim
using LinearAlgebra

show_plots = false

include("utils/zoh.jl")
show_plots && include("utils/recipes.jl")


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
    [0.0, 0.0, 3000000.0, -3000000.0, 0.0, 0.0],
)

mass_scaling = 0.6
three_bodies = (
    p = (
        G = 6.67430e-11,
        m1 = mass_scaling * 5e24,
        m2 = mass_scaling * 5e24,
        m3 = mass_scaling * 5e24,
    ),
    xc0 = x0,
    fc = fc_three_bodies,
    yc = yc_three_bodies,
)

T = 27 // 1
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

    p_logo_dark = plot(
        size = (500, 500),
        aspect_ratio = :equal,
        background_color = :transparent,
        axis = ([], false),
        legend = false,
    )

    plot!(
        p_logo_dark,
        r1_traj[:, 1],
        r1_traj[:, 2],
        color = "#eee",
        linewidth = strokewidth,
    )
    plot!(
        p_logo_dark,
        r2_traj[:, 1],
        r2_traj[:, 2],
        color = "#eee",
        linewidth = strokewidth,
    )
    plot!(
        p_logo_dark,
        r3_traj[:, 1],
        r3_traj[:, 2],
        color = "#eee",
        linewidth = strokewidth,
    )

    scatter!(
        p_logo_dark,
        [r1_traj[end, 1]],
        [r1_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_green,
        markersize = markersize,
    )
    scatter!(
        p_logo_dark,
        [r2_traj[end, 1]],
        [r2_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_red,
        markersize = markersize,
    )
    scatter!(
        p_logo_dark,
        [r3_traj[end, 1]],
        [r3_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_purple,
        markersize = markersize,
    )
    display(p_logo_dark)

    p_logo = plot(
        size = (500, 500),
        aspect_ratio = :equal,
        background_color = :transparent,
        axis = ([], false),
        legend = false,
    )

    plot!(p_logo, r1_traj[:, 1], r1_traj[:, 2], color = "#000", linewidth = strokewidth)
    plot!(p_logo, r2_traj[:, 1], r2_traj[:, 2], color = "#000", linewidth = strokewidth)
    plot!(p_logo, r3_traj[:, 1], r3_traj[:, 2], color = "#000", linewidth = strokewidth)

    scatter!(
        p_logo,
        [r1_traj[end, 1]],
        [r1_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_green,
        markersize = markersize,
    )
    scatter!(
        p_logo,
        [r2_traj[end, 1]],
        [r2_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_red,
        markersize = markersize,
    )
    scatter!(
        p_logo,
        [r3_traj[end, 1]],
        [r3_traj[end, 2]],
        markerstrokecolor = "#eee",
        markercolor = julia_purple,
        markersize = markersize,
    )
    display(p_logo)

    ### Logo Animation
    ##
    stroke_color = "#34495e"
    stroke_color_dark = "#ecf0f1"
    stroke_width = 15

    horizon_t = 5.0

    line_info = (width = stroke_width, color = stroke_color)
    planet_1_info = (markerstrokecolor = "#eee", markersize = 50, markercolor = julia_green)
    planet_2_info = (planet_1_info..., markercolor = julia_red)
    planet_3_info = (planet_1_info..., markercolor = julia_purple)


    fps_logo = 24
    Δt_logo = rationalize(1 / fps_logo)
    t_zoh, r_zoh = @zoh out.tcs out.xcs Δt_logo
    n = length(t_zoh)
    horizon = Int(round(horizon_t / Δt_logo))

    x_min = minimum(vcat(r_zoh[:, 1], r_zoh[:, 3], r_zoh[:, 5]))
    x_max = maximum(vcat(r_zoh[:, 1], r_zoh[:, 3], r_zoh[:, 5]))
    y_min = minimum(vcat(r_zoh[:, 2], r_zoh[:, 4], r_zoh[:, 6]))
    y_max = maximum(vcat(r_zoh[:, 2], r_zoh[:, 4], r_zoh[:, 6]))

    plot_info = (x_lims = 1.5 * [x_min, x_max], y_lims = 1.5 * [y_min, y_max])

    r1 = r_zoh[:, 1:2]
    r2 = r_zoh[:, 3:4]
    r3 = r_zoh[:, 5:6]

    line_info_dark = (line_info..., color = stroke_color_dark)
    anim = @animate for i ∈ 1:n
        logoanimation(i, r1, horizon, plot_info, line_info_dark, planet_1_info)
        logoanimation!(i, r2, horizon, plot_info, line_info_dark, planet_2_info)
        logoanimation!(
            i,
            r3,
            horizon,
            plot_info,
            line_info_dark,
            planet_3_info,
            background_color = "#282f2f",
        )
    end
    gif(anim, "docs/src/assets/logo-dark.gif", fps = fps_logo)

    line_info_light = (line_info..., color = stroke_color)
    anim = @animate for i ∈ 1:n
        logoanimation(i, r1, horizon, plot_info, line_info_light, planet_1_info)
        logoanimation!(i, r2, horizon, plot_info, line_info_light, planet_2_info)
        logoanimation!(
            i,
            r3,
            horizon,
            plot_info,
            line_info_light,
            planet_3_info,
            background_color = "#f5f5f5",
        )
    end
    gif(anim, "docs/src/assets/logo.gif", fps = fps_logo)
end

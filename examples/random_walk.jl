using SimpleSim

"""
    Random Walk

    see Examples > Random Walk on the official documentation.
    https://janneshb.github.io/SimpleSim.jl/dev/examples/random_walk/
"""

show_plots = false

params = (
    p_f = 0.25,
    p_b = 0.25,
    p_l = 0.25,
    p_r = 0.25,
)

function fd_random_walk(x, u, p, t; w)
    return x + w
end

yd_random_walk = (x, u, p, t; w) -> x

function wd_random_walk(x, u, p, t, rng)
    r = rand(rng)
    if r < p.p_f
        return [0, 1]
    elseif r < p.p_f + p.p_b
        return [0, -1]
    elseif r < p.p_f + p.p_b + p.p_l
        return [-1, 0]
    else
        return[1, 0]
    end
end

seed = 1234
random_walk_model = (
    p = params,
    fd = fd_random_walk,
    yd = yd_random_walk,
    wd = wd_random_walk,
    wd_seed = seed,
    xd0 = [0, 0],
    Δt = 1 // 1,
)

N = 100
data = simulate(random_walk_model, T = N // 1, options=(silent = true,))

if show_plots
    using Plots
    plotlyjs()
    p = plot(layout=(1, 1))
    plot!(p[1], data.yds[:, 1], data.yds[:, 2])

    T_animation = 3.0
    fps = Int(round(length(data.tds) / T_animation))
    animation = @animate for (i, t_i) in enumerate(data.tds)
        p_ani = plot(layout=(1, 1))
        plot!(p_ani[1], data.yds[1:i, 1], data.yds[1:i, 2], label="")
        scatter!(p_ani[1], [data.yds[i, 1]], [data.yds[i, 2]], markersize=7, label="", framestyle=:none, size=(500, 500), dpi=10, color="#000000") # bob

        xlims!(p_ani[1], minimum(data.yds[:, 1])-3, maximum(data.yds[:, 1])+3)
        ylims!(p_ani[1], minimum(data.yds[:, 2])-3, maximum(data.yds[:, 2])+3)
    end

    gif(animation, "examples/plots/random_walk_animation_$N.gif", fps = fps)
end

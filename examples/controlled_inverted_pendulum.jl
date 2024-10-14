using SimpleSim

show_plots = true

# PLANT
#
function fc_inv_pendulum(x, u, p, t)
    # state vector: [z, z', θ, θ']
    # F(t) = u(t)
    g = p.g
    m = p.m
    l = p.l
    l2 = l * l

    dz = x[2]
    θ = x[3]
    dθ = x[4]

    s_θ = sin(θ)
    c_θ = cos(θ)

    # nonlinear differential equations:
    # | m*ddz - m*l2*ddθ*cos(θ) + m*l2*dθ*dθ*sin(θ) = u
    # | l*ddθ - g*sin(θ) = ddz*cos(θ)
    #
    ddz = (u / m - g * s_θ * c_θ - l2 * dθ * dθ * s_θ) / (1 + c_θ * c_θ)
    ddθ = (ddz * c_θ + g * s_θ) / l
    return [dz, ddz, dθ, ddθ]
end

yc_inv_pendulum(x, u, p, t) = [x[3], x[4]]

inverted_pendulum = (
    p = (g = 9.81, l = 0.5, m = 0.3),
    xc0 = [0.0, 0.0, deg2rad(10.0), 0.0],
    uc0 = 0.0,
    fc = fc_inv_pendulum,
    yc = yc_inv_pendulum,
)

# CONTROLLER
#
function fc_controls(x, e, p, t)
    return [e[2], e[1]]
end

function yc_controls(x, e, p, t)
    p_part = p.k_p * x[1]
    i_part = p.k_i * x[2]
    d_part = p.k_d * e[2]
    return p_part + i_part + d_part
end

K = 1.5
controller = (
    p = (k_p = 30.0 * K, k_i = 20.0 * K, k_d = 20.0 * K),
    xc0 = [zeros(2)...],
    uc0 = [0.0, 0.0],
    fc = fc_controls,
    yc = yc_controls,
)

# CONTROLLED SYSTEM
#
function fc_controlled_system(x, r, p, t; models)
    return nothing # state-less, will not even be called
end

function yc_controlled_system(x, w, p, t; models)
    # compute error --> input to controller
    # note: e also contains ė
    r = [0.0, 0.0]
    y_prev = @out models.inverted_pendulum
    e = r - y_prev

    # call controller
    u = @call! models.controller e

    # call plant
    y = @call! models.inverted_pendulum (u + w)

    return y
end

controlled_system = (
    fc = fc_controlled_system,
    yc = yc_controlled_system,
    p = (),
    models = (inverted_pendulum = inverted_pendulum, controller = controller),
)

# RUN THE SIM
w = (t) -> 0.0 # reference
history = simulate(controlled_system, T = 10 // 1, uc = w)

if show_plots
    using Plots
    plotlyjs()
    include("utils/zoh.jl")

    ppt = plot(
        history.models.inverted_pendulum.tcs,
        history.models.inverted_pendulum.xcs[:, 3],
    )
    display(ppt)

    ppx = plot(
        history.models.inverted_pendulum.tcs,
        history.models.inverted_pendulum.xcs[:, 1],
    )
    display(ppx)

    fps = 10
    t_ani, X_ani =
        @zoh history.models.inverted_pendulum.tcs history.models.inverted_pendulum.xcs 1 /
                                                                                       fps

    x_min = minimum(X_ani[:, 1])
    x_max = maximum(X_ani[:, 1])
    x_delta = x_max - x_min

    x_min = x_min - x_delta / 5
    x_max = x_max + x_delta / 5

    cart_width = x_delta / 8
    cart_height = cart_width / 4

    L = 4 * inverted_pendulum.p.l

    rectangle(w, h, x, y) = Shape(x .+ [0, w, w, 0], y .+ [0, 0, h, h])

    # animation of the cart / pendulum
    println("Working on animation...")
    cart_pendulum_ani = @animate for i = 1:size(t_ani, 1)
        x_i = X_ani[i, 1]
        θ_i = X_ani[i, 3]

        # pendulum bob
        px = x_i + L * sin(θ_i)
        py = L * cos(θ_i)

        # plot the whole thing
        plot(
            [x_min, x_max],
            [0, 0],
            lw = 3,
            color = "#000000",
            label = "",
            aspect_ratio = 1,
            franestyle = :none,
        )
        plot!(
            rectangle(cart_width, cart_height, x_i - cart_width / 2, -cart_height / 2),
            label = "",
            color = "#000000",
        ) # cart
        plot!([x_i, px], [0, py], lw = 2, label = "", color = "#000000") # pendulum rod
        scatter!(
            [px],
            [py],
            markersize = 5,
            label = "",
            framestyle = :none,
            size = (500, 500),
            dpi = 10,
            color = "#000000",
        ) # bob

        xlims!(x_min - L, x_max + L)
        ylims!(-1.5 * L, 1.5 * L)
    end

    gif(cart_pendulum_ani, "examples/plots/pendulum_cart.gif", fps = fps)
end

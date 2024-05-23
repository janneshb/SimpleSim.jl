using Simulink
using StaticArrays

# PLANT
#
function fc_inv_pendulum(x, u, p, t; models)
    # state vector: [z, z', θ, θ']
    # F(t) = u(t)
    g = p.g
    m = p.m
    l = p.l
    l2 = l*l

    dz = x[2]
    θ = x[3]
    dθ = x[4]

    s_θ = sin(θ)
    c_θ = cos(θ)

    # nonlinear differential equations:
    # | m*ddz - m*l2*ddθ*cos(θ) + m*l2*dθ*dθ*sin(θ) = u
    # | l*ddθ - g*sin(θ) = ddz*cos(θ)
    #

    ddz = (u/m - g*s_θ*c_θ - l2*dθ*dθ*s_θ)/(1 + c_θ*c_θ)
    ddθ = (ddz*c_θ + g*s_θ) / l
    return SVector(dz, ddz, dθ, ddθ)
end

yc_inv_pendulum(x, u, p, t; models) = SVector(x[3], x[4])

inverted_pendulum = (
    p = (
        g = 9.81,
        l = 0.5,
        m = 0.3,
    ),
    xc0 = SVector(
        0.0,
        0.0,
        deg2rad(15.0),
        0.0
    ),
    uc0 = 0.0,
    fc = fc_inv_pendulum,
    yc = yc_inv_pendulum,
)

# CONTROLLER
#
function fc_controls(x, e, p, t; models)
    return SVector(e[2], e[1])
end

function yc_controls(x, u, p, t; models)
    return p.k_p*x[1] + p.k_i*x[2]
end

controller = (
    p = (
        k_p = 1.0,
        k_i = 0.1,
    ),
    xc0 = SVector(zeros(2)...),
    uc0 = SVector(zeros(2)...),
    fc = fc_controls,
    yc = yc_controls,
)

# CONTROLLED SYSTEM
#
function fc_controlled_system(x, r, p, t; models)
    return nothing # state-less, will not even be called
end

function yc_controlled_system(x, r, p, t; models)
    # compute error --> input to controller
    # note: e also contains ė
    e = r - models.inverted_pendulum.ycs[end]

    # call controller
    u = @call models.controller e

    # call plant
    y = @call models.inverted_pendulum u

    return y
end

controlled_system = (
    fc = fc_controlled_system,
    yc = yc_controlled_system,
    p = (),
    models = (
        inverted_pendulum = inverted_pendulum,
        controller = controller,
    )
)

# RUN THE SIM
#
r(t) = SVector(0.0, 0.0) # reference
history = simulate(controlled_system, T = 10.0, uc = r)
println("done.")

using Plots
plot(history.tcs, getindex.(history.ycs, 1))

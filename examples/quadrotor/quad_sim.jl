using SimpleSim
using StaticArrays
using LinearAlgebra
using Plots

include("quad_utils.jl")
include("quad_dynamics.jl")
include("quad_controller.jl")

p = (QuadParams(), CtrlParams())

# Initial state (hover at origin)
q0 = SVector(1.0, 0.0, 0.0, 0.0)
xc0 = vcat(zeros(3), zeros(3), q0, zeros(3))

# Discrete initial state [i_err_x, i_err_y, i_err_z, iter, motor1, motor2, motor3, motor4]
xd0 = vcat(zeros(3), 0, zeros(4))

model = (
    fc=fc_body,
    yc=gc_quad,
    fd=fd_pid,
    xc0=xc0,
    xd0=xd0,
    p=p,
    Δt=0.001)

# Simulate for 5 seconds
sim = simulate(model, T=5 // 1)
using StaticArrays
using LinearAlgebra

"""
Quadrotor physical parameters

# Args
- `m`: Total mass of quadrotor [kg]
- `J`: Inertia matrix [kg m²]
- `Jinv`: Inverse of inertia matrix [kg⁻¹ m⁻²]
- `l`: Arm length [m]
- `kT`: Propeller thrust constant [N s²]
- `d`: Propeller drag constant [Nm s²]
- `g`: Acceleration due to gravity [m s⁻²]
"""
mutable struct QuadParams
    m::Float64
    J::SMatrix{3,3,Float64,9}
    Jinv::SMatrix{3,3,Float64,9}
    l::Float64
    b::Float64
    d::Float64
    g::Float64

    # Constructor with default values
    function QuadParams(;
        m::Float64=1.5,
        J::SMatrix{3,3,Float64,9}=SMatrix{3,3}([0.03 0.0 0.0; 0.0 0.03 0.0; 0.0 0.0 0.05]),
        l::Float64=0.225,
        b::Float64=1.91e-6,
        d::Float64=2.6e-7,
        g::Float64=9.80665
    )
        Jinv = inv(J)
        new(m, J, Jinv, l, b, d, g)
    end
end

"""
Helper function to update inertia and its inverse together
"""
function update_inertia!(p::QuadParams, J::SMatrix{3,3,Float64,9})
    p.J = J
    p.Jinv = inv(J)
    return p
end

"""
Quadrotor body dynamics (continuous-time dynamical system)

# Args
- `x::Vector`: State vector containing (in order):
  - `r_B`: Position of body frame origin in world frame (3 elements)
  - `v_B`: Velocity of body frame origin in world frame (3 elements)
  - `q_WB`: Attitude of body frame in world frame (quaternion, 4 elements)
  - `B_ω_WB`: Angular velocity of body frame wrt world frame, expressed in body frame (3 elements)
- `u::Vector`: Control input vector containing motor thrusts [N] (4 elements)
- `p::QuadParams`: Quadrotor physical parameters
- `t`: Time

# Returns
- `Vector`: Time derivative of state vector

# Assumptions
- Body is a rigid X-configuration quadrotor, symmetric in xz and yz planes
- Body frame is forward-right-down (FRD) coordinate system, origin at center of gravity, aligned with quadrotor's principal axes
- Propellers are rigid, with rotation directions: 1 FL CCW, 2 FR CW, 3 RR CCW, 4 RL CW
- No fuselage drag
"""
function fc_body(x::Vector, u::Vector, p::QuadParams, t)::Vector
    r_B = SVector{3,Float64}(x[1:3])
    v_B = SVector{3,Float64}(x[4:6])
    q_WB = SVector{4,Float64}(x[7:10])
    B_ω_WB = SVector{3,Float64}(x[11:13])
    T_i = SVector{4,Float64}(u[1:4])

    # Thrust force
    B_F_T = SVector{3,Float64}(
        0.0,
        0.0,
        -sum(T_i)
    )

    R_WB = quat_to_R(q_WB)
    W_g = SVector{3,Float64}(0.0, 0.0, p.g)

    # Equation of forces (linear dynamics)
    a_B = (R_WB * B_F_T) / p.m + W_g

    # Thrust induced moment from propeller rotations
    B_M_T = SVector{3,Float64}(
        p.l * (T_i[4] - T_i[2]),
        p.l * (T_i[3] - T_i[1]),
        0.0
    )

    # Drag torques
    B_M_D = SVector{3,Float64}(
        0.0,
        0.0,
        p.d * (T_i[1] - T_i[2] + T_i[3] - T_i[4])
    )

    # Total aerodynamic moment
    B_M_Aero = B_M_T + B_M_D

    # Equation of moments (rotational dynamics)
    ωdot = p.Jinv * (B_M_Aero - cross(B_ω_WB, p.J * B_ω_WB))

    return vcat(v_B, a_B, qdot(q_WB, B_ω_WB), ωdot)
end

gc_quad = (x, u, p, t) -> x


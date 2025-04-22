using StaticArrays
using LinearAlgebra

"""
Controller parameters struct

# Fields
- `Kp_att`: Proportional gain for attitude controller [s⁻¹]
- `Kp_rate`: Proportional gain for rate controller [Nm s⁻¹]
- `Ki_rate`: Integral gain for rate controller [UNIT TODO]
- `Kd_rate`: Derivative gain for rate controller [UNIT TODO]
- `I_lim`: Integral error limit [Nm]
- `motor_lim`: Maximum motor force [N]
"""
struct CtrlParams
    Kp_att::SVector{3,Float64}
    Kp_rate::SVector{3,Float64}
    Ki_rate::SVector{3,Float64}
    Kd_rate::SVector{3,Float64}
    I_lim::Float64
    motor_lim::Float64

    # Constructor with default values
    function CtrlParams(;
        Kp_att::SVector{3,Float64}=SVector{3,Float64}(6.0, 6.0, 2.8),
        Kp_rate::SVector{3,Float64}=SVector{3,Float64}(0.15, 0.15, 0.10),
        Ki_rate::SVector{3,Float64}=SVector{3,Float64}(0.10, 0.10, 0.05),
        Kd_rate::SVector{3,Float64}=SVector{3,Float64}(0.003, 0.003, 0.0),
        I_lim::Float64=0.3,
        motor_lim::Float64=15.0
    )
        new(Kp_att, Kp_rate, Ki_rate, Kd_rate, I_lim, motor_lim)
    end
end

"""
fd: updates the controller every 1 ms.
xd = discrete state vector [i_err_x, i_err_y, i_err_z, iter, motor1, motor2, motor3, motor4]
xc = continuous state, p = tuple of (quad params, controller params)"""
function fd_pid(xd::Vector, xc::Vector, p::Tuple{QuadParams,CtrlParams}, t)
    # Unpack parameters
    qp, cp = p

    # Desired commands (for demo: hover level, zero yaw, altitude hold not implemented)
    q_sp = SVector(1.0, 0.0, 0.0, 0.0)      # level orientation, Quaternion [w,x,y,z]

    # Extract states
    q = SVector{4,Float64}(xc[7:10])
    ω = SVector{3,Float64}(xc[11:13])

    # Extract discrete state
    i_err = SVector{3,Float64}(xd[1:3])
    iter = Int(xd[4])
    prev_motor = SVector{4,Float64}(xd[5:8])

    # Attitude loop at 250 Hz (every 4 iterations)
    iter = iter + 1
    if iter % 4 == 0
        # quaternion error (q_err = q_sp ⊗ q⁻¹)
        q_inv = SVector(q[1], -q[2], -q[3], -q[4])
        q_err = qmul(q_sp, q_inv)
        # small-angle approx rotation vector (2*q_err_v) since w≈cos(θ/2)
        rot_vec = 2.0 * SVector{3,Float64}(q_err[2], q_err[3], q_err[4])
        # desired body rates
        ω_sp = cp.Kp_att .* rot_vec
    else
        ω_sp = i_err               # reuse last ω_sp (stored in i_err)
    end

    # Rate controller (1 kHz)
    rate_err = ω_sp - ω
    i_new = clamp.(i_err + cp.Ki_rate .* rate_err * 0.001, -cp.I_lim, cp.I_lim)
    τ_p = cp.Kp_rate .* rate_err
    τ_i = i_new
    τ_d = cp.Kd_rate .* (-ω)             # derivative term uses body rate derivative ≈-ω (simplified)
    τ_cmd = τ_p + τ_i + τ_d            # commanded torques [N·m]

    # Thrust command (hover) - distribute equally
    hover_T = qp.m * qp.g                  # N
    f_hover = hover_T / 4                # each motor equal for hover

    # Mixer: solve for motor forces (simplified linear mixer)
    # B * f = [T;τx;τy;τz]  with B as in comments above ⇒
    T_cmd = hover_T
    # torque coefficients projection to motors (solving analytic):
    kQ = qp.d / qp.b  # Compute kQ as d/b ratio (moment to thrust ratio)
    f1 = 0.25 * (T_cmd + τ_cmd[2] / qp.l - τ_cmd[3] / qp.l + τ_cmd[1] / kQ)
    f2 = 0.25 * (T_cmd - τ_cmd[2] / qp.l - τ_cmd[3] / qp.l - τ_cmd[1] / kQ)
    f3 = 0.25 * (T_cmd - τ_cmd[2] / qp.l + τ_cmd[3] / qp.l + τ_cmd[1] / kQ)
    f4 = 0.25 * (T_cmd + τ_cmd[2] / qp.l + τ_cmd[3] / qp.l - τ_cmd[1] / kQ)
    motor_cmd = SVector{4,Float64}(f1, f2, f3, f4)
    motor_cmd = clamp.(motor_cmd, 0.0, cp.motor_lim)  # limit to motor_lim N per motor

    # Return updated discrete state as concatenated vector
    return vcat(i_new, iter, motor_cmd)
end

using SimpleSim
using LinearAlgebra

perform_tests = false

### THE MOTORS
#
function fc_motor(ω, r_ω, p, t)
    ω_d = ω[2]
    ω_dd = (p.k * r_ω - 2 * p.ζ * p.τ * ω[2] - ω[1]) / p.τ^2

    if ω[1] >= p.rpm_max || ω[1] < 0.0
        ω_d = 0.0
        ω_dd = 0.0
    end

    return [ω_d, ω_dd]
end

gc_motor = (ω, r_ω, p, t) -> p.direction * ω[1]

motor_1 = (
    p = (τ = 0.075, ζ = 0.6, k = 1.0, rpm_max = 20_000 * 2 * π, direction = 1.0),
    fc = fc_motor,
    gc = gc_motor,
    xc0 = [0.0, 0.0],
    uc0 = 0.0,
)

motor_2 = motor_1
motor_3 = motor_1
motor_4 = motor_1

# motors 2 and 4 spin in the opposite direction
motor_2 = (motor_2..., p = (motor_2.p..., direction = -1.0))
motor_4 = (motor_4..., p = (motor_4.p..., direction = -1.0))


### THE PROPS
#
fc_prop = (x, ω, p, t) -> nothing
gc_prop = (x, ω, p, t) -> [p.k_f2 * ω^2, p.k_t * ω]

prop_1 = (p = (k_f2 = 5e-7, k_t = 2e-5), fc = fc_prop, gc = gc_prop, uc0 = 0.0)
prop_2 = prop_1
prop_3 = prop_1
prop_4 = prop_1


### THE RPM SENSORS
#
fd_rpm_sensor = (x, ω, p, t) -> nothing

gd_rpm_sensor = (x, ω, p, t) -> ω

rpm_sensor_1 =
    (p = nothing, fd = fd_rpm_sensor, gd = gd_rpm_sensor, Δt = 1 // 100, ud0 = 0.0)
rpm_sensor_2 = rpm_sensor_1
rpm_sensor_3 = rpm_sensor_1
rpm_sensor_4 = rpm_sensor_1


### THE "POWERED PROP"
#
fc_powered_prop = (x, u, p, t; models) -> nothing

function gc_powered_prop(x, r_ω, p, t; models)
    ω = @call! models.motor r_ω
    ft = @call! models.prop ω
    ω_measurement = @call! models.sensor ω

    return [ft..., ω_measurement...]
end

powered_prop_1 = (
    p = nothing,
    fc = fc_powered_prop,
    gc = gc_powered_prop,
    uc0 = 0.0,
    models = (motor = motor_1, prop = prop_1, sensor = rpm_sensor_1),
)

powered_prop_2 =
    (powered_prop_1..., models = (motor = motor_2, prop = prop_2, sensor = rpm_sensor_2))

powered_prop_3 =
    (powered_prop_1..., models = (motor = motor_3, prop = prop_3, sensor = rpm_sensor_3))

powered_prop_4 =
    (powered_prop_1..., models = (motor = motor_4, prop = prop_4, sensor = rpm_sensor_4))


### THE AIRFRAME
#
fc_airframe = (x, u, p, t; models) -> nothing

function gc_airframe(x, r_ω, p, t; models)
    ft_ω_1 = @call! models.powered_prop_1 r_ω[1]
    ft_ω_2 = @call! models.powered_prop_2 r_ω[2]
    ft_ω_3 = @call! models.powered_prop_3 r_ω[3]
    ft_ω_4 = @call! models.powered_prop_4 r_ω[4]

    # compute the total thrust in the drone's frame of reference
    f_total_B = [0, 0, -ft_ω_1[1] - ft_ω_2[1] - ft_ω_3[1] - ft_ω_4[1]]

    # compute total total torque
    t_aero_B = [0, 0, ft_ω_1[2] + ft_ω_2[2] + ft_ω_3[2] + ft_ω_4[2]]
    t_thrust_B =
        p.x_prop_1_B × [0, 0, ft_ω_1[1]] +
        p.x_prop_2_B × [0, 0, ft_ω_2[1]] +
        p.x_prop_3_B × [0, 0, ft_ω_3[1]] +
        p.x_prop_4_B × [0, 0, ft_ω_4[1]]
    t_prec_B = [0.0, 0.0, 0.0] # TODO

    return vcat(
        f_total_B,
        t_aero_B + t_thrust_B + t_prec_B,
        ft_ω_1[end],
        ft_ω_2[end],
        ft_ω_3[end],
        ft_ω_4[end],
    )
end

airframe = (
    p = ( # position of the rotors in the B frame
        x_prop_1_B = [10e-2, 10e-2, 0.0],
        x_prop_2_B = [-10e-2, 10e-2, 0.0],
        x_prop_3_B = [-10e-2, -10e-2, 0.0],
        x_prop_4_B = [10e-2, -10e-2, 0.0],
    ),
    fc = fc_airframe,
    gc = gc_airframe,
    uc0 = [0.0, 0.0, 0.0, 0.0],
    models = (
        powered_prop_1 = powered_prop_1,
        powered_prop_2 = powered_prop_2,
        powered_prop_3 = powered_prop_3,
        powered_prop_4 = powered_prop_4,
    ),
)


### Test Airframe
#
if perform_tests
    r_ω(t) = begin
        if t < 5
            return [0.0, 0.0, 0.0, 0.0]
        elseif t < 10
            return [1000 * 2 * π, 0.0, 0.0, 0.0]
        elseif t < 20
            return [10_000 * 2 * π, 0.0, 0.0, 0.0]
        elseif t < 30
            return [3000 * 2 * π, 0.0, 0.0, 0.0]
        else
            return 3000 * 2 * π * [1.0, 1.0, 1.0, 1.0]
        end
    end

    out_airframe = simulate(airframe, T = 40 // 1, uc = r_ω)

    using Plots
    plotlyjs()
    p1 = plot(
        out_airframe.tcs,
        norm.([out_airframe.ycs[i, 1:3] for i = 1:size(out_airframe.ycs, 1)]),
        title = "Prop Tests: Total Thrust",
        name = "f",
    )
    display(p1)

    p2 = plot(
        out_airframe.tcs,
        norm.([out_airframe.ycs[i, 4:6] for i = 1:size(out_airframe.ycs, 1)]),
        title = "Prop Tests: Total Torque",
        name = "τ",
    )
    display(p2)

    p3 = plot(layout = (4, 1), legend = false)
    p3 = plot!(
        p3[1],
        out_airframe.models.powered_prop_1.models.motor.tcs,
        out_airframe.models.powered_prop_1.models.motor.xcs[:, 1],
        title = "Prop Tests: RPM [rad/s]",
    )
    p3 = plot!(
        p3[2],
        out_airframe.models.powered_prop_2.models.motor.tcs,
        out_airframe.models.powered_prop_2.models.motor.xcs[:, 1],
    )
    p3 = plot!(
        p3[3],
        out_airframe.models.powered_prop_3.models.motor.tcs,
        out_airframe.models.powered_prop_3.models.motor.xcs[:, 1],
    )
    p3 = plot!(
        p3[4],
        out_airframe.models.powered_prop_4.models.motor.tcs,
        out_airframe.models.powered_prop_4.models.motor.xcs[:, 1],
    )
    #=
    plot!(
        out_airframe.models.motor_1.tcs,
        getindex.(r_ω.(out_airframe.models.motor_1.tcs), 1),
        label = "Ref",
    )
    =#
    display(p3)
end

### THE RIGID BODY
#
function fc_rigid_body(x, u, p, t)
    # rotation matrix B -> I
    R_IB = [
    # TODO
    ]

    # F_I = m a_I
    f_B = u[1:3]
    t_B = u[4:6]
    a_I = F_I / p.m

    # I ω_d_B  + ω_B × (I ω_B) = t_B
end

gc_rigid_body = (x, u, p, t) -> x

rigid_body = (
    p = (m = 0.3, J = [
        0.00675 0 0
        0 0.00675 0
        0 0 0.0135
    ]),
    fc = fc_rigid_body,
    gc = gc_rigid_body,
    xc0 = vcat(
        zeros(3), # pos (x, y, z), in inertial NED frame
        zeros(3), # vel (u, v, w), in inertial NED frame
        zeros(3), # euler angles (roll, pitch, yaw)
        zeros(3), # angular rates (p, q, r) in body frame
    ),
    uc0 = vcat(
        zeros(3), # forces
        zeros(3), # torque
    ),
)

### SENSORS
# TODO: add noise and drift to sensors
fd_gps = (x, u, p, t) -> nothing
gd_gps = (x, u, p, t) -> return x
gps_module = (
    p = nothing,
    fd = fd_gps,
    gd = gd_gps,
    Δt = 1 // 1, # GPS is pretty slow
)

fd_acc = (x, u, p, t) -> [t, u...] # store current time and input (velocity)
gd_acc = (x, u, p, t) -> (u - x[2:end]) / (t - x[1]) # numerically estimate acceleration
accelerometer = (p = nothing, fd = fd_acc, gd = gd_acc, Δt = 1 // 400)

fd_gyro = (x, u, p, t) -> nothing
gd_gyro = (x, u, p, t) -> x
gyroscope = (p = nothing, fd = fd_gyro, gd = gd_gyro, Δt = 1 // 250)

# TODO: add barometer

#### Combining all sensors into a sensor suite
fc_sensor_suite = (x, u, p, t; models) -> nothing

function gc_sensor_suite(x, u, p, t; models)
    gps_read = @call! models.gps x[1:3]
    accelerometer_read = @call! models.acc x[4:6]
    gyro_read = @call! models.gyro x[10:12]
    # TODO
    return nothing
end

sensor_suite = (
    p = nothing,
    fc = fc_sensor_suite,
    gc = gc_sensor_suite,
    models = (gps = gps_module, acc = accelerometer, gyro = gyroscope),
)

### THE CONTROL SYSTEM
#
function fd_control(x, u, p, t)
    return nothing
end

function gd_control(x, u, p, t)
    # TODO
    return x
end

controls =
    (p = nothing, fd = fd_control, gd = gd_control, Δt = 1 // 20, ud0 = [0.0, 0.0, 0.0])

### THE TASK MANAGER - decides where we go and when
fd_task_manager = (x, u, p, t) -> nothing

function gd_task_manager(x, u, p, t)
    if t < 10
        # take-off
        return [0.0, 0.0, -1.0]
    elseif t < 20
        # to height
        return [0.0, 0.0, -5.0]
    elseif t < 25
        return [1.0, 0.0, -5.0]
    elseif t < 30
        return [1.0, 1.0, -5.0]
    elseif t < 40
        return [0.0, 0.0, -1.0]
    else
        return [0.0, 0.0, 0.0]
    end
end

task_manager = (p = (), fd = fd_task_manager, gd = gd_task_manager, Δt = 1 // 1)

### THE DRONE
#
function fc_drone(x, u, p, t; models)
    return nothing
end

function gc_drone(x, u, p, t; models)
    return x
end

drone = (
    p = nothing,
    fc = fc_drone,
    gc = gc_drone,
    models = (
        task_manager = task_manager,
        controls = controls,
        airframe = airframe,
        rigid_body = rigid_body,
        sensor_suite = sensor_suite,
    ),
)

print_model_tree(drone)

using SimpleSim
using Revise

perform_tests = false

### THE MOTORS
function fc_motor(ω, r_ω, p, t)
    ω_d = ω[2]
    ω_dd = (p.k * r_ω - 2 * p.ζ * p.τ * ω[2] - ω[1]) / p.τ^2

    if ω[1] >= p.rpm_max || ω[1] < 0.0
        ω_d = 0.0
        ω_dd = 0.0
    end

    return [ω_d, ω_dd]
end

yc_motor = (ω, r_ω, p, t) -> p.direction * ω[1]

motor_1 = (
    p = (τ = 0.075, ζ = 0.6, k = 1.0, rpm_max = 20_000 * 2 * π, direction = 1.0),
    fc = fc_motor,
    yc = yc_motor,
    xc0 = [0.0, 0.0],
    uc0 = 0.0,
)

motor_2 = motor_1
motor_3 = motor_1
motor_4 = motor_1

motor_2 = (motor_2..., p = (motor_2.p..., direction = -1.0))
motor_4 = (motor_4..., p = (motor_4.p..., direction = -1.0))

### THE PROPS
fc_prop = (x, ω, p, t) -> nothing
yc_prop = (x, ω, p, t) -> [p.k_f2 * ω^2, p.k_t * ω]

prop_1 = (p = (k_f2 = 5e-7, k_t = 2e-5), fc = fc_prop, yc = yc_prop, uc0 = 0.0)
prop_2 = prop_1
prop_3 = prop_1
prop_4 = prop_1

### THE SENSORS
fd_sensor = (x, ω, p, t) -> nothing

yd_sensor = (x, ω, p, t) -> ω

sensor_1 = (p = nothing, fd = fd_sensor, yd = yd_sensor, Δt = 1 // 100, ud0 = 0.0)
sensor_2 = sensor_1
sensor_3 = sensor_1
sensor_4 = sensor_1

### THE AIRFRAME
fc_airframe = (x, u, p, t; models) -> nothing

function yc_airframe(x, r_ω, p, t; models)
    rpm_1 = @call! models.motor_1 r_ω[1]
    rpm_2 = @call! models.motor_2 r_ω[2]
    rpm_3 = @call! models.motor_3 r_ω[3]
    rpm_4 = @call! models.motor_4 r_ω[4]

    @call! models.sensor_1 rpm_1
    @call! models.sensor_2 rpm_2
    @call! models.sensor_3 rpm_3
    @call! models.sensor_4 rpm_4

    ft_1 = @call! models.prop_1 rpm_1
    ft_2 = @call! models.prop_2 rpm_2
    ft_3 = @call! models.prop_3 rpm_3
    ft_4 = @call! models.prop_4 rpm_4

    return ft_1 + ft_2 + ft_3 + ft_4
end

airframe = (
    p = nothing,
    fc = fc_airframe,
    yc = yc_airframe,
    uc0 = [0.0, 0.0, 0.0, 0.0],
    models = (
        motor_1 = motor_1,
        sensor_1 = sensor_1,
        prop_1 = prop_1,
        motor_2 = motor_2,
        sensor_2 = sensor_2,
        prop_2 = prop_2,
        motor_3 = motor_3,
        sensor_3 = sensor_3,
        prop_3 = prop_3,
        motor_4 = motor_4,
        sensor_4 = sensor_4,
        prop_4 = prop_4,
    ),
)

### Test Airframe
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
    p1 = plot(out_airframe.tcs, out_airframe.ycs[:, 1], title = "Thrust")
    display(p1)

    p2 = plot(out_airframe.tcs, out_airframe.ycs[:, 2], title = "Torque")
    display(p2)

    p3 = plot(
        out_airframe.models.motor_1.tcs,
        out_airframe.models.motor_1.xcs[:, 1],
        label = "RPM",
        title = "RPM Prop 1",
    )
    plot!(
        out_airframe.models.motor_1.tcs,
        getindex.(r_ω.(out_airframe.models.motor_1.tcs), 1),
        label = "Ref",
    )
    display(p3)
end

### THE RIGID BODY
function fc_rigid_body(x, u, p, t)
    # TODO
    return nothing
end

yc_rigid_body = (x, u, p, t) -> x

rigid_body = (p = (m = 0.2, J = [
]), fc = fc_rigid_body, yc = yc_rigid_body, xc0 = [], uc0 = [])

### THE CONTROL SYSTEM
function fd_control(x, u, p, t)
    return nothing
end

function yd_control(x, u, p, t)
    return x
end

controls = (p = (
), fd = fd_control, yd = yd_control, Δt = 1 // 20, ud0 = [0.0, 0.0, 0.0])

### THE TASK MANAGER - decides where we go and when
fd_task_manager = (x, u, p, t) -> nothing

function yd_task_manager(x, u, p, t)
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

task_manager = (p = (
), fd = fd_task_manager, yd = yd_task_manager, Δt = 1 // 1)

### THE DRONE
function fc_drone(x, u, p, t; models)
    return nothing
end

function yc_drone(x, u, p, t; models)
    return x
end

drone = (
    p = nothing,
    fc = fc_drone,
    yc = yc_drone,
    models = (
        task_manager = task_manager,
        controls = controls,
        airframe = airframe,
        rigid_body = rigid_body,
    ),
)

print_model_tree(drone)

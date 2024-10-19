# Four-Rotor Drone

In this example, a four-rotor drone, just as the , is set up. Roughly speaking, the drone involves the following individual models:

* a rigid body
* motors
* propellers
* sensors
* a control system

Some of these models only consist of continuous-time or discrete-time dynamics, other might have both.

Of course, the system's complexity can be increased arbitrarily.

A rough block diagram of the system is given below.

```@raw html
<object class="pdf" data="../../assets/FourRotorDrone.pdf" style="width: 100%; align: center; min-height: 350px;"></object>
<br>
Click <a href="../../assets/FourRotorDrone.pdf" target="_blank">here</a> to open the diagram in a new tab for closer inspection.
```

## Motors

The motors' RPM are modeled as second-order systems with time-constant $\tau$, damping $\zeta$ and gain $k$.

```math
\tau \frac{d^2 \omega}{d t^2} + 2 \zeta \tau \frac{d\omega}{dt} + \omega = k \cdot r_\omega(t)
```

The reference RPM supplied by the control system forms the motor input.

For `SimpleSim.jl` we need to cast this ODE into a system of first-order ODEs. The state then consists of the RPM $\omega$ and its derivative $\dot{\omega}$.

```julia
function fc_motor(ω, r_ω, p, t)
    ω_d = ω[2]
    ω_dd = (p.k * r_ω - 2 * p.ζ * p.τ * ω[1]) / p.τ

    if ω[1] >= p.rpm_max || ω[1] <= 0.0
        ω_d = 0.0
        ω_dd = 0.0
    end

    return [ω_d, ω_dd]
end
```

The output only contains the current RPM.

```julia
gc_motor = (ω, r_ω, p, t) -> p.direction * ω[1]
```

We can then create a motor model. The parameters $\tau$, $\zeta$ and $k$ are identified using system identification techniques. All motors are assumed to standing still at the beginning of the simulation.

```julia
motor_1 = (
    p = (
        τ = 1 / 800.0^2,
        ζ = 0.15,
        k = 1.0,
        rpm_max = 20_000*2*π,
        direction = 1.0,
    ),
    fc = fc_motor,
    gc = gc_motor,
    xc0 = [0.0, 0.0],
    uc0 = 0.0,
)
```

All four motors are basically identical. Hence, we copy the model we already have to get all four motor models.

```julia
motor_2 = motor_1
motor_3 = motor_1
motor_4 = motor_1
```

We only need to adjust the direction of rotation for motor 2 and 4.

```julia
motor_2 = (motor_2..., p = (motor_2.p..., direction = -1.0))
motor_4 = (motor_4..., p = (motor_4.p..., direction = -1.0))
```

_Note:_ we are speaking about RPM, but $ω$ is actually measured in radians per second.

## Propellers

We expect propellers to generate linear force (thrust) and torque as a function of the current RPM of the rotor. RPM is therefore an input of a rotor model, thrust and torque are the output.

Thrust always acts downwards in the drone's frame of reference. Torque depends only on the direction of rotation of the propeller. Hence, we can use scalar values as ouputs of the propeller model.

```julia
fc_prop = (x, ω, p, t) -> nothing

gc_prop = (x, ω, p, t) -> [p.k_f2 * ω^2, p.k_t * ω]
```

We expect thrust to be proportional to the square of the rate of rotation, while torque behaves approximately linear with respect to $\omega$. The slopes $k_{f, 2}$ and $k_t$ are given as parameters.

```julia
prop_1 = (
    p = (
        k_f2 = 5e-7,
        k_t = 2e-5,
    ),
    fc = fc_prop,
    gc = gc_prop,
    uc0 = 0.0,
)
prop_2 = prop_1
prop_3 = prop_1
prop_4 = prop_1
```

## RPM Sensors

We assume the motors provide RPM feedback. But the sensor for that is digital and only updates at a frequency of 100Hz.

```julia
fd_sensor = (x, ω, p, t) -> nothing

gd_sensor = (x, ω, p, t) -> ω

sensor_1 = (
    p = nothing,
    fd = fd_sensor,
    gd = gd_sensor,
    Δt = 1 // 100,
    ud0 = 0.0,
)
sensor_2 = sensor_1
sensor_3 = sensor_1
sensor_4 = sensor_1
```

Naturally, all sensors should be purely discrete-time.

## "Powered" Propellers

This model is not strictly necessary. However, to showcase the modularity of `SimpleSim.jl` we will wrap a motor, propeller and RPM sensor


```julia
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
    models = (
        motor = motor_1,
        prop = prop_1,
        sensor = rpm_sensor_1,
    )
)

powered_prop_2 = (powered_prop_1...,
    models = (
        motor = motor_2,
        prop = prop_2,
        sensor = rpm_sensor_2,
    )
)

powered_prop_3 = # ...
```

A `powered_prop` is a continuous-time model, taking a reference RPM as input. It then calls the motor model, computes the thrust and torque generated using the prop model and returns the force, torque and the sensor measurement of the current RPM.

## Airframe

To gather the motor and propeller models, we define a state-less airframe model that simply computes the overall force and torque acting on the system, given four reference RPM values.

Note, that since the propellers are excerted from the drone's center of gravity they need to be included in the computation of the total torque acting on the system.

```julia
fc_airframe = (x, u, p, t; models) -> nothing

function gc_airframe(x, r_ω, p, t; models)
    ft_ω_1 = @call! models.powered_prop_1 r_ω[1]
    ft_ω_2 = @call! models.powered_prop_2 r_ω[2]
    ft_ω_3 = @call! models.powered_prop_3 r_ω[3]
    ft_ω_4 = @call! models.powered_prop_4 r_ω[4]

    # compute the total thrust in the drone's frame of reference
    f_total_B = [0, 0, - ft_ω_1[1] - ft_ω_2[1] - ft_ω_3[1] - ft_ω_4[1]]

    # compute total total torque
    t_aero_B = [0, 0, ft_ω_1[2] + ft_ω_2[2] + ft_ω_3[2] + ft_ω_4[2]]
    t_thrust_B = p.x_prop_1_B × [0, 0, ft_ω_1[1]] + p.x_prop_2_B × [0, 0, ft_ω_2[1]] + p.x_prop_3_B × [0, 0, ft_ω_3[1]] + p.x_prop_4_B × [0, 0, ft_ω_4[1]]

    return vcat(f_total_B, t_aero_B + t_thrust_B, ft_ω_1[end], ft_ω_2[end], ft_ω_3[end], ft_ω_4[end])
end

airframe = (
    p = (
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
```

## The Rigid Body

The drone itself of course has rigid body dynamics. These are pretty straigtforward to model.

The rigid-body inputs are the sum of all forces and moments acting on the body in its own frame of reference. The output is its current position and velocity in the inertial frame and its Euler angles, as well as angular rates.

```julia
function fc_rigid_body(x, u, p, t)

end

gc_rigid_body = (x, u, p, t) -> x

rigid_body = (
    p = (
        m = 0.3,
        J = [

        ],
    ),
    fc = fc_rigid_body,
    gc = gc_rigid_body,
    xc0 = [],
    uc0 = [],
)
```

## Sensor Suite


## State Estimation


## Control System


## Putting it all together
```julia
the_drone = (
    models = (
        airframe = airframe,
    )
)
```

## Adding an Atmosphere

## Remote Controls

## Software in the Loop

# Four-Rotor Drone

In this example, a four-rotor drone, just as the ones you can buy from various manufacturers, is set up. The drone involves the following individual models:

* a rigid body
* motors
* rotors
* sensors
* a control system

Some of these models only consist of continuous-time or discrete-time dynamics, other might have both.

Of course, the system's complexity can be increased arbitrarily.

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
yc_motor = (ω, r_ω, p, t) -> p.direction * ω[1]
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
    yc = yc_motor,
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

yc_prop = (x, ω, p, t) -> [p.k_f2 * ω^2, p.k_t * ω]
```

We expect thrust to be proportional to the square of the rate of rotation, while torque behaves approximately linear with respect to $\omega$. The slopes $k_{f, 2}$ and $k_t$ are given as parameters.

```julia
prop_1 = (
    p = (
        k_f2 = 5e-7,
        k_t = 2e-5,
    ),
    fc = fc_prop,
    yc = yc_prop,
    uc0 = 0.0,
)
prop_2 = prop_1
prop_3 = prop_1
prop_4 = prop_1
```

## The Sensors

We assume the motors provide RPM feedback. But the sensor for that is digital and only updates at a frequency of 100Hz.

```julia
fd_sensor = (x, ω, p, t) -> nothing

yd_sensor = (x, ω, p, t) -> ω

sensor_1 = (
    p = nothing,
    fd = fd_sensor,
    yd = yd_sensor,
    Δt = 1 // 100,
    ud0 = 0.0,
)
sensor_2 = sensor_1
sensor_3 = sensor_1
sensor_4 = sensor_1
```

## The Airframe

To gather the motor and propeller models, we define a state-less airframe model that simply computes the overall force and torque acting on the system, given four refernce RPM values.

```julia
fc_airframe = (x, u, p, t; models) -> nothing

function yc_airframe(x, r_ω, p, t; models)
    rpm_1 = @call! models.motor_1 r_ω[1]
    rpm_2 = @call! models.motor_2 r_ω[1]
    rpm_3 = @call! models.motor_3 r_ω[1]
    rpm_4 = @call! models.motor_4 r_ω[1]

    [f_1, t_1] = @call! models.
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
```

## The Rigid Body

The drone itself of course has rigid body dynamics. These are pretty straigtforward to model.

The rigid-body inputs are the sum of all forces and moments acting on the body in its own frame of reference. The output is its current position and velocity in the inertial frame and its Euler angles, as well as angular rates.

```julia
function fc_rigid_body(x, u, p, t)
    
end

yc_rigid_body = (x, u, p, t) -> x

rigid_body = (
    p = (
        m = 0.2,
        J = [

        ],
    ),
    fc = fc_rigid_body,
    yc = yc_rigid_body,
    xc0 = [],
    uc0 = [],
)
```

## The Control System


## Putting it all together
```julia
the_drone = (
    models = (
        airframe = airframe,
    )
)
```
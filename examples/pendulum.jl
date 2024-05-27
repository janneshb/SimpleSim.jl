using SimpleSim
using StaticArrays

# dynamic rule for the damped pendulum
fc_pendulum(x, u, p, t) = SVector(x[2], -p.λ*x[2] - p.ω2*sin(x[1]))

# measurement model
yc_pendulum(x, u, p, t) = x

x0 = [
    30.0 *π/180.0,   #*s/s,
    0.0              #*1/s
]
pendulum = (
    p = (
        g = 9.81,
        L = 0.5,
        ω2 = 9.81/0.5, # equals g/L
        λ = 0.3,
    ),
    xc0 = x0,
    fc = fc_pendulum,
    yc = yc_pendulum,
)


T = 30 // 1
u(t) = 0.0

history = simulate(pendulum, T = T, uc = u)

using Plots
plot(history.tcs, getindex.(history.ycs, 1))

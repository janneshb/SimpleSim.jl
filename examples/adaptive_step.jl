using SimpleSim
using StaticArrays

show_plots = true

fc_adaptive_step(x, u, p, t) = 1 + x*x

yc_adaptive_step(x, u, p, t) = x

x0 = 0.0

adaptive_step = (
    p = (),
    xc0 = x0,
    fc = fc_adaptive_step,
    yc = yc_adaptive_step,
)

T = 14 // 10

out_euler = simulate(adaptive_step, T = T, integrator = Euler)
out_heun = simulate(adaptive_step, T = T, integrator = Heun)
out_rk4 = simulate(adaptive_step, T = T, integrator = RK4)
out_rkf45 = simulate(adaptive_step, T = T, integrator = RKF45)

if show_plots
    using Plots
    p1 = plot(
        out_rk4.tcs,
        out_rk4.xcs,
        label="RK4",
    )
    plot!(
        out_euler.tcs,
        out_euler.xcs,
        label="Euler",
    )
    plot!(
        out_heun.tcs,
        out_heun.xcs,
        label="Heun",
    )
    plot!(
        out_rkf45.tcs,
        out_rkf45.xcs,
        label="RKF45",
    )
    plot!(
        out_rkf45.tcs,
        tan.(out_rkf45.tcs),
        xlabel = "t",
        ylabel = "y",
        label="Exact"
    )
    display(p1)
end

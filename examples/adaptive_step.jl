using SimpleSim
using BenchmarkTools

"""
    Adaptive Step Demonstration

    This example implements the differential equation x' = 1 + x^2.
    The ODE is solved using different solvers and the results are plotted (if show_plots = true).

    From the plots it is obvious that the adaptive RKF45 algorithm performs best.
"""

show_plots = false

fc_adaptive_step(x, u, p, t) = 1 + x * x

gc_adaptive_step(x, u, p, t) = x

x0 = 0.0

adaptive_step = (p = (), xc0 = x0, fc = fc_adaptive_step, gc = gc_adaptive_step)

T = 15 // 10

println("Simulating via Euler method...")
out_euler =
    @btime simulate(adaptive_step, T = T, integrator = Euler, options = (silent = true,))

println("Simulating via Heun method...")
out_heun =
    @btime simulate(adaptive_step, T = T, integrator = Heun, options = (silent = true,))

println("Simulating via RK4 method...")
out_rk4 =
    @btime simulate(adaptive_step, T = T, integrator = RK4, options = (silent = true,))

println("Simulating via adaptive RKF45 method...")
out_rkf45 =
    @btime simulate(adaptive_step, T = T, integrator = RKF45, options = (silent = true,))

out_exact = (tcs = out_rkf45.tcs, xcs = tan.(out_rkf45.tcs))

if show_plots
    using Plots
    plotlyjs()
    p1 = plot(out_rk4.tcs, out_rk4.xcs, label = "RK4")
    plot!(out_euler.tcs, out_euler.xcs, label = "Euler")
    plot!(out_heun.tcs, out_heun.xcs, label = "Heun")
    plot!(out_rkf45.tcs, out_rkf45.xcs, label = "RKF45")
    plot!(out_exact.tcs, out_exact.xcs, xlabel = "t", ylabel = "y", label = "Exact")
    display(p1)
end

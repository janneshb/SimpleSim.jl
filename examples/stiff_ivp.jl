using SimpleSim

show_plots = false

function fc_stiff_ivp(x, u, p, t)
    x_dot = -2 * x + exp(-2 * (t - 6)^2)
    return x_dot
end

function gc_stiff_ivp(x, u, p, t)
    return x
end

x0 = 1.0
stiff_ivp = (p = (), xc0 = x0, fc = fc_stiff_ivp, gc = gc_stiff_ivp)

T = 10 // 1
Δt = 5 // 100
out_euler = simulate(stiff_ivp, T = T, Δt_max = Δt, integrator = Euler)
out_heun = simulate(stiff_ivp, T = T, Δt_max = Δt, integrator = Heun)
out_rk4 = simulate(stiff_ivp, T = T, Δt_max = Δt, integrator = RK4)
out_rkf45 = simulate(stiff_ivp, T = T, Δt_max = Δt, integrator = RKF45)


if show_plots
    using Plots
    plotlyjs()
    p1 = plot(out_euler.tcs, out_euler.xcs, xlabel = "t", ylabel = "x", name = "Euler")
    plot!(out_heun.tcs, out_heun.xcs, name = "Heun")
    plot!(out_rk4.tcs, out_rk4.xcs, name = "RK4")
    plot!(out_rkf45.tcs, out_rkf45.xcs, name = "RKF45")
    display(p1)
end

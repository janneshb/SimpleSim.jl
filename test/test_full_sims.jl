@testset "Full Simulations" begin
    @testset "ODE Solver" begin
        x_exact = (x) -> tan(x)

        Δt_max = 1 // 100
        T = 15 // 10
        x0 = 0.0
        fc_ode(x, u, p, t) = 1 + x * x
        yc_ode(x, u, p, t) = x

        ode_system = (p = (;), xc0 = x0, fc = fc_ode, yc = yc_ode)

        out_euler = simulate(
            ode_system,
            T = T,
            integrator = Euler,
            options = (silent = true, Δt_max = Δt_max),
        )
        out_heun = simulate(
            ode_system,
            T = T,
            integrator = Heun,
            options = (silent = true, Δt_max = Δt_max),
        )
        out_rk4 = simulate(
            ode_system,
            T = T,
            integrator = RK4,
            options = (silent = true, Δt_max = Δt_max),
        )
        out_rkf45 = simulate(
            ode_system,
            T = T,
            integrator = RKF45,
            options = (silent = true, Δt_max = Δt_max),
        )

        mse_euler = mean((out_euler.xcs .- x_exact.(out_euler.tcs)) .^ 2)
        mse_heun = mean((out_heun.xcs .- x_exact.(out_heun.tcs)) .^ 2)
        mse_rk4 = mean((out_rk4.xcs .- x_exact.(out_rk4.tcs)) .^ 2)
        mse_rkf45 = mean((out_rkf45.xcs .- x_exact.(out_rkf45.tcs)) .^ 2)

        # check that all sims have completed successfully
        @test out_euler.tcs[end] == T
        @test out_heun.tcs[end] == T
        @test out_rk4.tcs[end] == T
        @test abs(T - out_rkf45.tcs[end]) <= Δt_max

        # sims should be increasingly better
        @test mse_heun < mse_euler
        @test mse_rk4 < mse_heun
        @test mse_rkf45 < mse_rk4
    end

    @testset "Fricton-less Bouncing Ball (zero-crossing detection)" begin
        x0 = [0, 3.0, 0, 0]
        fc_bouncing_ball(x, u, p, t) = [x[3], x[4], 0.0, -1.0 * p.g]
        yc_bouncing_ball(x, u, p, t) = [x[1], x[2]]
        zc_bouncing_ball(x, p, t) = x[2]
        zc_exec_bouncing_ball(x, u, p, t) = [x[1], x[2], x[3], -p.ε * x[4]]

        bouncing_ball = (
            p = (g = 9.81, ε = 1.0),
            xc0 = x0,
            fc = fc_bouncing_ball,
            yc = yc_bouncing_ball,
            zc = zc_bouncing_ball,
            zc_exec = zc_exec_bouncing_ball,
        )

        T = 156 // 100
        out = simulate(
            bouncing_ball,
            T = T,
            integrator = RK4,
            Δt_max = 1 // 100,
            options = (silent = true, zero_crossing_tol = 1e-5),
        )
        @test maximum(abs.(out.xcs[end, :] - x0)) < 0.05
    end

    @testset "Full Simulation CT" begin


    end

    @testset "Full Simulation DT" begin


    end

    @testset "Full Simulation Hybrid / Nested" begin


    end
end

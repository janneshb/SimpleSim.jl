@testset "Full Simulations" begin
    @testset "ODE Solver" begin
        x_exact = (x) -> tan(x)

        Δt_max = 1 // 100
        T = 15 // 10
        x0 = 0.0
        fc_ode(x, u, p, t) = 1 + x * x
        gc_ode(x, u, p, t) = x

        ode_system = (p = (;), xc0 = x0, fc = fc_ode, gc = gc_ode)

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
        gc_bouncing_ball(x, u, p, t) = [x[1], x[2]]
        zc_bouncing_ball(x, p, t) = x[2]
        zc_exec_bouncing_ball(x, u, p, t) = [x[1], x[2], x[3], -p.ε * x[4]]

        bouncing_ball = (
            p = (g = 9.81, ε = 1.0),
            xc0 = x0,
            fc = fc_bouncing_ball,
            gc = gc_bouncing_ball,
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

    @testset "Bouncing Ball with Friction (zero-crossing detection, will eventually fail)" begin
        x0 = [0, 3.0, 3.0, 0]
        fc_bouncing_ball(x, u, p, t) = [x[3], x[4], 0.0, -1.0 * p.g]
        gc_bouncing_ball(x, u, p, t) = [x[1], x[2]]
        zc_bouncing_ball(x, p, t) = x[2]
        zc_exec_bouncing_ball(x, u, p, t) = [x[1], x[2], x[3], -p.ε * x[4]]

        bouncing_ball = (
            p = (g = 9.81, ε = 0.8),
            xc0 = x0,
            fc = fc_bouncing_ball,
            gc = gc_bouncing_ball,
            zc = zc_bouncing_ball,
            zc_exec = zc_exec_bouncing_ball,
        )

        T = 8 // 1
        out = simulate(
            bouncing_ball,
            T = T,
            integrator = RK4,
            Δt_max = 1 // 100,
            options = (silent = true, zero_crossing_tol = 1e-5),
        )
    end

    @testset "Controlled Spring-Damper System" begin
        fc_spring_damper = (x, u, p, t) -> [x[2], -p.k * x[1] - p.c * x[2] + u]
        gc_spring_damper = (x, u, p, t) -> x[1]
        spring_damper = (
            p = (k = 0.2, c = 0.3),
            fc = fc_spring_damper,
            gc = gc_spring_damper,
            xc0 = [0.0, 0.0],
        )

        Δt_controller = 1 // 10
        fd_controller = (x, u, p, t) -> [p.k_p * u + x[2] + p.k_i * p.Δt * u, x[1]]
        gd_controller = (x, u, p, t) -> x[1]
        controller = (
            p = (k_p = 0.002, k_i = 0.035, Δt = Δt_controller),
            fd = fd_controller,
            gd = gd_controller,
            Δt = Δt_controller,
            xd0 = [0.0, 0.0],
        )

        fc_system = (x, u, p, t, models) -> nothing
        function gc_system(x, r, p, t; models)
            xc_spring_damper = @state models.spring_damper # state CT
            yc_spring_damper = @out models.spring_damper # out CT

            xd_controller = @state models.controller
            yd_controller = @out models.controller

            e = r - yc_spring_damper
            controller_y = @call! models.controller e # calling DT
            spring_damper_y = @call! models.spring_damper controller_y # calling CT
            return [
                spring_damper_y,
                xc_spring_damper...,
                yc_spring_damper...,
                xd_controller...,
                yd_controller...,
            ]
        end

        system = (
            fc = fc_system,
            gc = gc_system,
            models = (spring_damper = spring_damper, controller = controller),
        )

        out = simulate(system, T = 60 // 1, uc = (t) -> 1.0, options = (silent = true,))
        @test abs(out.ycs[end, 1] - 1.0) < 0.01

        # test @out and @state macros
        @test all(out.ycs[:, 2] .== out.ycs[:, 4])
        @test all(out.ycs[:, 5] .== out.ycs[:, 7])

        # print the system for full coverage ;-)
        buffer = IOBuffer()
        print_model_tree(buffer, system)
        @test length(take!(buffer)) > 0
        flush(buffer)
    end

    @testset "Hybrid Integration" begin
        fc_integration = (x, u, p, t) -> 1.0
        gc_integration = (x, u, p, t) -> x
        fd_integration = (x, u, p, t) -> x + p.Δt
        gd_integration = (x, u, p, t) -> x

        Δt = 1 // 10
        hybrid_integrator = (
            p = (Δt = Δt,),
            fc = fc_integration,
            gc = gc_integration,
            xc0 = 0.0,
            fd = fd_integration,
            gd = gd_integration,
            xd0 = 0.0,
            Δt = Δt,
        )
        out = simulate(hybrid_integrator, T = 5 // 1, options = (silent = true,))
        @test abs(out.yds[end] - out.ycs[end]) < 1e-4

        function fc_hybrid_integrator_parent(x, u, p, t; models)
            # these will throw errors
            x_sub = @state models.submodel
            y_sub = @out models.submodel
            return nothing
        end

        function gc_hybrid_integrator_parent(x, u, p, t; models)
            y_sub = @call! models.submodel nothing
            return y_sub
        end

        hybrid_integrator_parent = (
            fc = fc_hybrid_integrator_parent,
            gc = gc_hybrid_integrator_parent,
            models = (submodel = hybrid_integrator,),
        )
        out_nested =
            simulate(hybrid_integrator_parent, T = 5 // 1, options = (silent = true,))
    end

    @testset "Parallel Submodels" begin
        fc_integration = (x, u, p, t) -> 1.0
        gc_integration = (x, u, p, t) -> x
        fd_integration = (x, u, p, t) -> x + p.Δt
        gd_integration = (x, u, p, t) -> x

        ct_integrator = (fc = fc_integration, gc = gc_integration, xc0 = 0.0)

        Δt = 1 // 10
        dt_integrator =
            (p = (Δt = Δt,), fd = fd_integration, gd = gd_integration, xd0 = 0.0, Δt = Δt)

        function fc_parent(x, u, p, t; models)
            y_1 = @out models[1]
            y_2 = @out models[2]

            x_1 = @state models[1]
            x_2 = @state models[2]

            return [x_1, x_2]
        end

        function gc_parent(x, u, p, t; models)
            y_1 = @call! models[1] nothing
            y_2 = @call! models[2] nothing

            return [y_1, y_2]
        end

        parent_1 = (fc = fc_parent, gc = gc_parent, models = [ct_integrator, dt_integrator])

        parent_2 = (fc = fc_parent, gc = gc_parent, models = (ct_integrator, dt_integrator))

        out_1 = simulate(parent_1, T = 5 // 1, options = (silent = true,))
        out_2 = simulate(parent_2, T = 5 // 1, options = (silent = true,))

        @test abs(out_1.ycs[end, 1] - out_1.ycs[end, 2]) < 1e-4
        @test abs(out_2.ycs[end, 1] - out_2.ycs[end, 2]) < 1e-4
    end

    @testset "Faulty Simulation" begin
        fc_minimal = (x, u, p, t) -> 1.0
        gc_minimal = (x, u, p, t) -> x
        minimal_ct_model = (
            fc = fc_minimal,
            gc = gc_minimal,
            xc0 = 1, # different type than needed, this should be 1.0
        )

        fd_minimal = (x, u, p, t) -> x + p.Δt
        gd_minimal = (x, u, p, t) -> x
        minimal_dt_model = (
            p = (Δt = 1 // 10,),
            fd = fd_minimal,
            gd = gd_minimal,
            xd0 = 1, # different type than needed, this should be 1.0
            Δt = 1 // 10,
        )

        fc_parent = (x, u, p, t; models) -> nothing
        function gc_parent(x, u, p, t; models)
            for i in eachindex(models)
                @call! models[i] nothing
            end
            return 1.0
        end
        parent =
            (fc = fc_parent, gc = gc_parent, models = (minimal_ct_model, minimal_dt_model))

        mega_parent =
            (fc = fc_parent, gc = gc_parent, models = (parent, parent, minimal_ct_model))

        buffer = IOBuffer()
        print_model_tree(buffer, mega_parent)
        @test length(take!(buffer)) > 0
        flush(buffer)
        out_mega_parent = simulate(mega_parent, T = 1 // 1, options = (silent = true,))

        fd_parent = (x, u, p, t; models) -> nothing
        function gd_parent(x, u, p, t; models)
            for i in eachindex(models)
                @call! models[i] nothing
            end
            return 1.0
        end
        dt_parent = (
            fd = fd_parent,
            gd = gd_parent,
            models = (minimal_ct_model, minimal_dt_model),
            Δt = 1 // 10,
        )
        out_dt_parent = simulate(dt_parent, T = 1 // 1, options = (silent = true,)) # this throws warnings because of calling CT models from within DT models
    end

    @testset "Random Walk" begin
        fd_random_walk = (x, u, p, t; w) -> x + w
        gd_random_walk = (x, u, p, t; w) -> x
        wd_random_walk = (x, u, p, t, rng) -> rand(rng, -1:1)

        random_walk = (
            Δt = 1 // 1,
            xd0 = 0,
            fd = fd_random_walk,
            gd = gd_random_walk,
            wd = wd_random_walk,
            wd_seed = 1234,
        )
        out = simulate(random_walk, T = 5 // 1, options = (silent = true,))
        @test out.xds[end] == 1

        fd_random_walk_faulty = (x, u, p, t; w) -> [x + w]
        gd_random_walk_faulty = (x, u, p, t; w) -> x
        wd_random_walk_faulty = (x, u, p, t, rng) -> t < 3 ? rand(rng, -1:1) : 0.5

        random_walk_faulty = (
            Δt = 1 // 1,
            xd0 = 0,
            fd = fd_random_walk_faulty,
            gd = gd_random_walk_faulty,
            wd = wd_random_walk_faulty,
            wd_seed = 1234,
        )
        out_faulty = simulate(random_walk_faulty, T = 5 // 1, options = (silent = true,))
        @test out_faulty.xds == 0
    end
end

@testset "Integrators" begin
    @testset "Discrete-Time Steps" begin
        @testset "autonomous, no input" begin
            fd = (x, u, p, t) -> x + 1
            x_next = 0
            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, nothing, (;), nothing)
            @test x_next == 1

            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, nothing, (;), nothing)
            @test x_next == 2

            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, nothing, (;), nothing)
            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, nothing, (;), nothing)
            @test x_next == 4
        end
        @testset "non-autonomous, no input" begin
            fd = (x, u, p, t) -> x^2 + t / 2
            x_next = 0
            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, 0 // 1, (;), nothing)
            @test x_next == 0

            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, 1 // 2, (;), nothing)
            @test x_next == 1 // 4

            x_next = SimpleSim.step_dt(fd, x_next, nothing, nothing, 1 // 1, (;), nothing)
            @test x_next == 9 // 16
        end
        @testset "non-autonomous, with inputs and parameters" begin
            fd = (x, u, p, t) -> p.a * x^-4 + p.b * u^3 + p.c * t^2
            u = (t) -> cos(t)
            t = 0:0.1:1
            x_next = 0.1
            p = (a = 1 // 2, b = 0.75, c = 4)
            for t_i in t
                x_next = SimpleSim.step_dt(fd, x_next, u(t_i), p, t_i, (;), nothing)
            end
            @test abs(x_next - 4.121917564762489) < 1e-6
        end
    end

    @testset "Forward Euler" begin
        # dx/dt = -x, x(0) = 1, exact solution x(t) = exp(-t).
        # Step from t=0 to t=1 with dt=0.01 and compare to exp(-1).
        # Euler is first-order: global error scales as O(dt) ~ 0.01.
        fc = (x, u, p, t) -> -x
        Δt = 1 // 100
        x = 1.0
        t = 0 // 1
        while t < 1 // 1
            x, _ = SimpleSim.step_ct(Δt, fc, x, nothing, nothing, t, (;); integrator = Euler)
            t += Δt
        end
        @test abs(x - exp(-1.0)) < 5e-3   # first-order global error bound
    end

    @testset "Heun's Method / Explicit Trapezoidal" begin
        # Same exponential decay problem as the Euler test.
        # Heun is second-order: global error scales as O(dt^2) ~ 1e-4, so roughly
        # 50x more accurate than Euler for the same step size.
        fc = (x, u, p, t) -> -x
        Δt = 1 // 100
        x = 1.0
        t = 0 // 1
        while t < 1 // 1
            x, _ = SimpleSim.step_ct(Δt, fc, x, nothing, nothing, t, (;); integrator = Heun)
            t += Δt
        end
        @test abs(x - exp(-1.0)) < 1e-4   # second-order global error bound
    end

    @testset "4th Order Runge-Kutta" begin
        # Same exponential decay problem.
        # RK4 is fourth-order: global error scales as O(dt^4) ~ 1e-8,
        # dramatically more accurate than Heun for the same step size.
        fc = (x, u, p, t) -> -x
        Δt = 1 // 100
        x = 1.0
        t = 0 // 1
        while t < 1 // 1
            x, _ = SimpleSim.step_ct(Δt, fc, x, nothing, nothing, t, (;); integrator = RK4)
            t += Δt
        end
        @test abs(x - exp(-1.0)) < 1e-7   # fourth-order global error bound
    end

    @testset "Runge-Kutta-Fehlberg" begin
        # RKF45 embeds a 4th and 5th order RK formula and uses their difference
        # as a truncation error estimate to adapt the step size.

        # Part 1: single-step accuracy on the smooth exponential decay problem.
        # The RK5 local error is O(dt^6), so one step of dt=0.01 should match
        # the exact solution to near machine precision.
        fc = (x, u, p, t) -> -x
        x_rkf45, Δt_out = SimpleSim.step_ct(
            1 // 100, fc, 1.0, nothing, nothing, 0 // 1, (;); integrator = RKF45,
        )
        @test abs(x_rkf45 - exp(-0.01)) < 1e-12  # RK5 per-step error
        @test Δt_out ≈ 0.01                        # smooth problem: no step reduction needed

        # Part 2: adaptive step reduction on a stiff problem.
        # dx/dt = -50x with dt=0.1 produces a large truncation error, so step_rkf45
        # recurses with a smaller dt and returns the accepted (smaller) step.
        fc_stiff = (x, u, p, t) -> -50.0 * x
        _, Δt_adapted = SimpleSim.step_rkf45(
            1 // 10, fc_stiff, 1.0, nothing, nothing, 0 // 1, (;),
        )
        @test Δt_adapted < 0.1   # step was reduced to meet the tolerance
    end

    @testset "Step CT Dispatch" begin
        fc = (x, u, p, t) -> 0.5 * x + u * t + p.a
        Δt = 1 // 100

        x = 0.5
        u = 0.3
        t = 1 // 3
        p = (a = 3,)

        x_next_rk4, Δt_rk4 = SimpleSim.step_ct(Δt, fc, x, u, p, t, (;))
        x_next_rk4_kwarg, Δt_rk4_kwarg =
            SimpleSim.step_ct(Δt, fc, x, u, p, t, (;), integrator = RK4)

        @test Δt_rk4 == 1 // 100
        @test abs(x_next_rk4 - 0.5335989147890625) < 1e-6
        @test abs(x_next_rk4 - x_next_rk4_kwarg) < 1e-6
        @test abs(Δt_rk4 - Δt_rk4_kwarg) < 1e-6
    end

    @testset "State-less Systems" begin
        fd = (x, u, p, t) -> nothing
        fc = (x, u, p, t) -> nothing

        x_dt = SimpleSim.step_dt(fd, nothing, nothing, nothing, nothing, (;), nothing)
        x_ct, Δt =
            SimpleSim.step_ct(1 // 10, fd, nothing, nothing, nothing, nothing, (;), nothing)

        @test isnothing(x_dt)
        @test isnothing(x_ct)
        @test Δt == 1 // 10
    end

    @testset "StaticArrays SVector States" begin
        # SimpleSim uses only generic Julia arithmetic (+, *, /) so SVector initial
        # states work out of the box — all intermediate values stay stack-allocated.

        # CT: 2D harmonic oscillator, compare SVector vs Vector results
        fc_ho = (x, u, p, t) -> SA[x[2], -x[1]]
        x0_vec = [0.0, 1.0]
        x0_static = SA[0.0, 1.0]
        Δt = 1 // 100

        x_vec, _ = SimpleSim.step_ct(Δt, fc_ho, x0_vec, nothing, nothing, 0 // 1, (;))
        x_static, _ = SimpleSim.step_ct(Δt, fc_ho, x0_static, nothing, nothing, 0 // 1, (;))

        @test x_static isa SVector
        @test x_vec ≈ collect(x_static)

        # Full simulate() with SVector initial state
        model = (xc0 = SA[0.0, 1.0], fc = fc_ho, gc = (x, u, p, t) -> x)
        out = simulate(model, T = 1 // 1, options = (silent = true,))

        @test out.xcs isa Matrix
        @test size(out.xcs, 2) == 2
        @test out.tcs[end] == 1 // 1
        # first component should approximate sin(t): x[1](t=1) ≈ sin(1)
        @test abs(out.xcs[end, 1] - sin(1.0)) < 1e-6

        # DT: SVector state in a discrete-time model
        fd_dt = (x, u, p, t) -> SA[x[1] + 1, x[2] - 1]
        gd_dt = (x, u, p, t) -> x
        model_dt = (xd0 = SA[0, 0], fd = fd_dt, gd = gd_dt, Δt = 1 // 10)
        out_dt = simulate(model_dt, T = 1 // 1, options = (silent = true,))

        @test out_dt.xds isa Matrix
        @test out_dt.xds[end, 1] == 10
        @test out_dt.xds[end, 2] == -10
    end
end

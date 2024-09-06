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

    end

    @testset "Heun's Method / Explicit Trapezoidal" begin

    end

    @testset "4th Order Runge-Kutta" begin

    end

    @testset "Runge-Kutta-Fehlberg" begin

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
end

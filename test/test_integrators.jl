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
            # fd = (x, u, p, t) -> x^2 + t/2
        end
        @testset "non-autonomous, with inputs" begin

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
end

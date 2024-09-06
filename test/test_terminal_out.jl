@testset "Terminal Output" begin
    # Running a sim with all output enabled
    Δt_max = 1 // 100
    T = 15 // 10
    x0 = 0.0
    fc_ode(x, u, p, t) = 1 + x * x
    yc_ode(x, u, p, t) = x

    ode_system = (p = (;), xc0 = x0, fc = fc_ode, yc = yc_ode)

    buffer = IOBuffer(read = true, write = true)
    out_euler = simulate(
        ode_system,
        T = T,
        integrator = RK4,
        Δt_max = Δt_max,
        options = (
            silent = false,
            debug = true,
            display_progress = true,
            progress_spacing = 1 // 1,
            out_stream = buffer,
            Δt_max = Δt_max,
        ),
    )
    @test length(String(take!(buffer))) > 0
    flush(buffer)
end

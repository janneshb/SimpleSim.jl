using Documenter
using SimpleSim

pages = [
    "Introduction" => "index.md",
    "Manual" => [
        "API" => "manual/api.md",
        "Continuous-Time Models" => "manual/ct_sims.md",
        "Discrete-Time Models" => "manual/dt_sims.md",
        "Nested Models" => "manual/nested_sims.md",
        "Simulating Models" => "manual/run_sims.md",
        "Interpreting Output" => "manual/output.md",
    ],
    "Examples" => [
        "Minimal Example" => "examples/minimal_example.md",
        "Bouncing Ball" => "examples/bouncing_ball.md",
        "Feedback Control" => "examples/feedback_control.md",
        "Random Walk" => "examples/random_walk.md",
        "Four-Rotor Drone" => "examples/four_rotor_drone.md",
    ],
    "Running Simulations" => [
        "Standalone Simulations" => "functions/standalone_sim.md",
        "Nested Simulations" => "functions/nested_sim.md",
        "Random Variables" => "functions/random_vars.md",
        "Zero-Crossing Detection" => "functions/zero_crossing.md",
    ],
    "Output Handling" => [
        "Simulation Output" => "output/simulation_output.md",
        "`@log` macro" => "output/log.md",
    ],
    "Integrators" => [
        "Overview" => "integrators/overview.md",
        "Euler" => "integrators/euler.md",
        "Heun" => "integrators/heun.md",
        "4th Order Runge-Kutta" => "integrators/rk4.md",
        "Runge-Kutta-Fehlberg" => "integrators/rkf45.md",
    ],
    "Miscellaneous" => "misc.md",
]

println("Making Documentation...")

makedocs(
    modules = [SimpleSim],
    sitename = "SimpleSim.jl",
    pagesonly = true,
    draft = false,
    pages = pages,
    format = Documenter.HTML(;
        assets = [asset("assets/custom.css", class = :css, islocal = true)],
        collapselevel = 3,
    ),
    warnonly = [:missing_docs, :cross_references],
)
println("Done!\n")

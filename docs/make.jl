using Documenter
using SimpleSim

pages = [
    "Introduction" => "index.md",
    "API" => "manual/api.md",
    "Manual" => [
        "Setting up Models" => [
            "Continuous-Time Models" => "manual/ct_sims.md",
            "Discrete-Time & Hybrid Models" => "manual/dt_sims.md",
            "Nested Models" => "manual/nested_sims.md",
            "Zero-Crossing Detection" => "manual/zero_crossing.md",
            "Random Variables" => "manual/random_vars.md",
        ],
        "Running Simulations" => "manual/run_sims.md",
        "Supported Integrators" => [
            "Overview" => "integrators/overview.md",
            "Euler" => "integrators/euler.md",
            "Heun" => "integrators/heun.md",
            "4th Order Runge-Kutta" => "integrators/rk4.md",
            "Runge-Kutta-Fehlberg" => "integrators/rkf45.md",
        ],
        "Simulation Output" => "manual/output.md",
        "Miscellaneous" => "manual/misc.md",
    ],
    "Examples" => [
        "Minimal Example" => "examples/minimal_example.md",
        "Bouncing Ball" => "examples/bouncing_ball.md",
        "Random Walk" => "examples/random_walk.md",
        #"Feedback Control" => "examples/feedback_control.md",
        #"Four-Rotor Drone" => "examples/four_rotor_drone.md",
    ],
]

println("Making Documentation...")

makedocs(
    modules = [SimpleSim],
    sitename = "SimpleSim.jl",
    pagesonly = true,
    draft = false,
    pages = pages,
    format = Documenter.HTML(;
        assets = [
            asset("assets/custom.css", class = :css, islocal = true),
        ],
        collapselevel = 3,
    ),
    warnonly = [:missing_docs, :cross_references],
)
println("Done!\n")

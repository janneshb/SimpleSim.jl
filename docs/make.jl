using Documenter
using SimpleSim

pages = [
    "Introduction" => "index.md",
    "Overview" => [
        "Continuous-Time Models" => "overview/ct_sims.md",
        "Discrete-Time Models" => "overview/dt_sims.md",
        "Nested Models" => "overview/nested_sims.md",
        "Simulating Models" => "overview/run_sims.md",
        "Interpreting Output" => "overview/output.md",
    ],
    "Examples" => [
        "Minimal Example" => "examples/minimal_example.md",
        "Bouncing Ball" => "examples/bouncing_ball.md",
        "Feedback Control" => "examples/feedback_control.md",
        "Random Walk" => "examples/random_walk.md",
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
        assets = [
            asset("assets/custom.css", class=:css, islocal=true),
        ],
        collapselevel = 3,
    ),
    warnonly = [:missing_docs, :cross_references],
)
println("Done!\n")

println("Deploying Documentation...")
# deploydocs(repo = "github.com/janneshb/SimpleSim.jl.git")
println("Done!")

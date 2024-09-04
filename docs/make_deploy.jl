include("make.jl")

println("Deploying Documentation...")
deploydocs(
    devbranch = "docs",
    repo = "github.com/janneshb/SimpleSim.jl.git"
)
println("Done!")

include("make.jl")

println("Deploying Documentation...")
deploydocs(repo = "github.com/janneshb/SimpleSim.jl.git")
println("Done!")

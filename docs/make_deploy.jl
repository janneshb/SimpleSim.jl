include("make.jl")

println("Deploying Documentation...")
deploydocs(devbranch = "main", repo = "github.com/janneshb/SimpleSim.jl.git")
println("Done!")

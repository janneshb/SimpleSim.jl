using Documenter
using SimpleSim

pages = ["Introduction" => "index.md", "Overview" => "overview.md"]

println("Making Documentation...")
makedocs(
    modules = [SimpleSim],
    format = Documenter.HTML(),
    sitename = "SimpleSim.jl",
    pagesonly = true,
    draft = false,
    pages = pages,
    warnonly = [:missing_docs, :cross_references],
)
println("Done!\n")

println("Deploying Documentation...")
# deploydocs(repo = "github.com/janneshb/SimpleSim.jl.git")
println("Done!")

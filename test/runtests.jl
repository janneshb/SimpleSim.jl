using SimpleSim
using Test

@testset "Examples" begin
    include("../examples/controlled_inverted_pendulum.jl")
    include("../examples/discrete_pendulum.jl")
    include("../examples/hybrid_pendulum.jl")
    include("../examples/pendulum.jl")
    include("../examples/timing.jl")
end

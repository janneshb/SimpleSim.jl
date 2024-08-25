using SimpleSim
using Test

using Suppressor

@testset "Examples" begin
    @suppress_out begin
        include("../examples/controlled_inverted_pendulum.jl")
        include("../examples/discrete_pendulum.jl")
        include("../examples/hybrid_pendulum.jl")
        include("../examples/pendulum.jl")
        include("../examples/timing.jl")
        include("../examples/bouncing_ball.jl")
        include("../examples/random_draws.jl")
        include("../examples/adaptive_step.jl")
    end
end

println("Done testing!")

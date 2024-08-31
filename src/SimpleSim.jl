module SimpleSim

using Random
import Base.push!, Base.@inline, Base.gcd

global DEFAULT_Δt = 1 // 100 # default step size for CT systems, must be rational!
global Δt_MIN = 1 // 1_000_000
global DEFAULT_zero_crossing_precision = 1e-5
global RKF45_REL_TOLERANCE = 1e-6
global RKF45_MIN_ABS_ERR = 1e-7
global DEBUG = true
global DISPLAY_PROGRESS = false
global PROGRESS_SPACING = 1 // 1 # in the same unit as total time T
global BASE_RNG = MersenneTwister

include("macros.jl")
include("enums.jl")

# DO NOT CHANGE THESE GLOBAL VARIABLES
global MODEL_CALLS_DISABLED = false
global CONTEXT = ContextUnknown::SimulationContext
global MODEL_COUNT = 0

include("utils.jl")
include("core.jl")
include("access.jl")
include("info.jl")
include("output.jl")
include("integrators.jl")
include("misc.jl")

end # module SimpleSim

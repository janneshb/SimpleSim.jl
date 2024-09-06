module SimpleSim

using Random
import Logging.Info, Logging.Debug, Logging.SimpleLogger, Logging.global_logger
import Base.push!, Base.@inline, Base.gcd

global VERSION = "0.1.0"
global YEAR = "2024"
global AUTHORS = "Jannes Huehnerbein"

global ΔT_DEFAULT = 1 // 100 # default step size for CT systems, must be rational!
global ΔT_MIN = 1 // 1_000_000
global ZERO_CROSSING_TOL = 1e-5
global RKF45_REL_TOL = 1e-6
global RKF45_ABS_TOL = 1e-7
global DEBUG = false
global DISPLAY_PROGRESS = true
global PROGRESS_SPACING = 1 // 1 # in the same unit as total time T
global SILENT = false
global BASE_RNG = MersenneTwister
global OUT_STREAM = nothing

include("macros.jl")
include("enums.jl")

# DO NOT CHANGE THESE GLOBAL VARIABLES
global DEFAULT_CONFIG = @gather_default_config
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
include("preamble.jl")

end # module SimpleSim

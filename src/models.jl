export AbstractModel, AbstractCTModel, AbstractDTModel, AbstractHybridModel
abstract type AbstractModel end
abstract type AbstractCTModel <: AbstractModel end
abstract type AbstractDTModel <: AbstractModel end
abstract type AbstractHybridModel <: AbstractModel end

export CTModel
Base.@kwdef struct CTModel <: AbstractCTModel
    p
    fc
    gc
    zc = nothing
    zc_exec = nothing
    xc0 = nothing
    uc0 = nothing
    models = nothing
end

export DTModel
Base.@kwdef struct DTModel <: AbstractDTModel
    p
    fd
    gd
    Δt
    wd = nothing
    xd0 = nothing
    ud0 = nothing
    models = nothing
end

export HybridModel
Base.@kwdef struct HybridModel <: AbstractHybridModel
    p
    fc
    gc
    fd
    gd
    Δt
    zc = nothing
    zc_exec = nothing
    wd = nothing
    xc0 = nothing
    uc0 = nothing
    xd0 = nothing
    ud0 = nothing
    models = nothing
end

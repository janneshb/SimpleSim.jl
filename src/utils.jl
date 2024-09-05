@inline check_rational(x) = _check_rational(x)
@inline _check_rational(x::Rational{Int64}) = x
@inline _check_rational(x::Int) = x
@inline _check_rational(x::AbstractFloat) = begin
    !SILENT &&
    @error "Timesteps and durations should be given as `Rational` to avoid timing errors."
    x
end
@inline _check_rational(x) = oneunit(x) * _check_rational(x.val) # assume it's a Unitful.jl Quantity
gcd(x, y) = oneunit(x) * Base.gcd(x.val, y.val) # for Unitful.jl Quantities

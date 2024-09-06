@inline check_rational(x) = _check_rational(x)
@inline _check_rational(x::Rational{T}) where {T<:Integer} = x
@inline _check_rational(x::Int) = x // 1
@inline _check_rational(x::AbstractFloat) = begin
    !SILENT &&
    @error "Timesteps and durations should be given as `Rational` to avoid timing errors."
    rationalize(x)
end
@inline _check_rational(x) = oneunit(x) * _check_rational(x.val) # assume it's a Unitful.jl Quantity
gcd(x, y) = oneunit(x) * Base.gcd(x.val, y.val) # for Unitful.jl Quantities

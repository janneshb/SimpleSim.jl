using StaticArrays
using LinearAlgebra

"""
Skew-symmetric matrix of a vector

# Args
- `v::SVector{3,Float64}`: Vector

# Returns
- `SMatrix{3,3,Float64}`: Skew-symmetric matrix
"""
@inline function skew(v::SVector{3,Float64})
    SMatrix{3,3,Float64}([0.0 -v[3] v[2];
        v[3] 0.0 -v[1];
        -v[2] v[1] 0.0])
end

"""
Quaternion multiplication (q ⊗ p)

# Args
- `q::SVector{4,Float64}`: Quaternion
- `p::SVector{4,Float64}`: Quaternion

# Returns
- `SVector{4,Float64}`: Quaternion
"""
@inline function qmul(q::SVector{4,Float64}, p::SVector{4,Float64})
    w1, x1, y1, z1 = q
    w2, x2, y2, z2 = p
    SVector(w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2)
end

"""
Quaternion to rotation matrix

# Args
- `q::SVector{4,Float64}`: Quaternion

# Returns
- `SMatrix{3,3,Float64}`: Rotation matrix
"""
@inline function quat_to_R(q::SVector{4,Float64})
    w, x, y, z = q
    ww, xx, yy, zz = w * w, x * x, y * y, z * z
    wx, wy, wz = w * x, w * y, w * z
    xy, xz, yz = x * y, x * z, y * z
    SMatrix{3,3,Float64}(
        [ww+xx-yy-zz 2(xy-wz) 2(xz+wy);
            2(xy+wz) ww-xx+yy-zz 2(yz-wx);
            2(xz-wy) 2(yz+wx) ww-xx-yy+zz])
end

"""
Quaternion time derivative given angular velocity

# Args
- `q::SVector{4,Float64}`: Quaternion
- `ω::SVector{3,Float64}`: Angular velocity

# Returns
- `SVector{4,Float64}`: Quaternion time derivative
"""
@inline function qdot(q::SVector{4,Float64}, ω::SVector{3,Float64})
    Ω = SMatrix{4,4,Float64}([0.0 -ω[1] -ω[2] -ω[3];
        ω[1] 0.0 ω[3] -ω[2];
        ω[2] -ω[3] 0.0 ω[1];
        ω[3] ω[2] -ω[1] 0.0])
    0.5 * (Ω * q)
end
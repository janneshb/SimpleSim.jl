using Overdot
using StaticArrays


function fc_inner_ct(x, u, p, t; models)
    return 1.0
end
yc_inner_ct(x, u, p, t; models) = x

inner_ct = (
    p = (),
    xc0 = 0.0,
    uc0 = 0.0,
    fc = fc_inner_ct,
    yc = yc_inner_ct,
)


function fd_inner_dt2(x, u, p, t; models)
    return t
end

function yd_inner_dt2(x, u, p, t; models)
    return x
end
inner_dt2 = (
    p = (),
    xd0 = 0.0,
    ud0 = 0.0,
    fd = fd_inner_dt2,
    yd = yd_inner_dt2,
    Δt = 1.0,
)


function fd_inner_dt(x, u, p, t; models)
    return t
end

function yd_inner_dt(x, u, p, t; models)
    y2 = @call! models.inner_dt2 0.0
    return y2
end
inner_dt = (
    p = (),
    xd0 = 0.0,
    ud0 = 0.0,
    fd = fd_inner_dt,
    yd = yd_inner_dt,
    Δt = 0.3,
    models = (
        inner_dt2 = inner_dt2,
    )
)


fc_wrapper(x, u, p, t; models) = nothing

function yc_wrapper(x, u, p, t; models)
    y_ct_inner = @call! models.inner_ct 0.0
    y_dt_inner = @call! models.inner_dt 0.0
    return 1.0
end
wrapper = (
    p = (),
    fc = fc_wrapper,
    yc = yc_wrapper,
    models = (
        inner_ct = inner_ct,
        inner_dt = inner_dt,
    )
)

history = simulate(wrapper, T = 3.0)
println("done.")

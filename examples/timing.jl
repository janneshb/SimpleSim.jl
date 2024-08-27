using SimpleSim
using StaticArrays

show_plots = false

function fc_inner_hybrid(x, u, p, t)
    return 1.0
end
yc_inner_hybrid(x, u, p, t) = x

function fd_inner_hybrid(x, u, p, t)
    return t
end
yd_inner_hybrid(x, u, p, t) = x

inner_hybrid = (
    p = (),
    xc0 = 0.0,
    uc0 = 0.0,
    fc = fc_inner_hybrid,
    yc = yc_inner_hybrid,
    xd0 = 0.0,
    ud0 = 0.0,
    fd = fd_inner_hybrid,
    yd = yd_inner_hybrid,
    Δt = 5 // 10,
)


function fd_inner_dt2(x, u, p, t)
    return t
end

function yd_inner_dt2(x, u, p, t)
    return x
end
inner_dt2 =
    (p = (), xd0 = 0.0, ud0 = 0.0, fd = fd_inner_dt2, yd = yd_inner_dt2, Δt = 1 // 10)


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
    Δt = 3 // 10,
    models = (inner_dt2 = inner_dt2,),
)


fc_wrapper(x, u, p, t; models) = nothing

function yc_wrapper(x, u, p, t; models)
    y_ct_inner = @call_ct! models.inner_hybrid 0.0
    y_dt_inner = @call_dt! models.inner_hybrid 0.0
    y_dt_inner2 = @call! models.inner_dt 0.0
    return 1.0
end
wrapper = (
    p = (),
    fc = fc_wrapper,
    yc = yc_wrapper,
    models = (inner_hybrid = inner_hybrid, inner_dt = inner_dt),
)

history = simulate(wrapper, T = 3 // 1)

if show_plots
    using Plots
    plotlyjs()
    plot(
        history.models.inner_hybrid.tcs,
        history.models.inner_hybrid.ycs,
        size = (1000, 1000),
        label = "hybrid CT",
    )
    plot!(
        history.models.inner_hybrid.tds,
        history.models.inner_hybrid.yds,
        seriestype = :steppost,
        label = "hybrid DT",
    )
    plot!(
        history.models.inner_dt.tds,
        history.models.inner_dt.yds,
        seriestype = :steppost,
        label = "DT 1",
    )
    plot!(
        history.models.inner_dt.models.inner_dt2.tds,
        history.models.inner_dt.models.inner_dt2.yds,
        seriestype = :steppost,
        label = "DT 2",
    )
end

using SimpleSim

function fc_inner(x, u, p, t)
    return 0.5 * x
end

function yc_inner(x, u, p, t)
    return x
end

inner_model = (p = nothing, fc = fc_inner, yc = yc_inner, xc0 = 1.0)


function fd_outer(x, u, p, t; models)
    return nothing
end

function yd_outer(x, u, p, t; models)
    y_inner = @call! models.inner_model nothing # this is illegal and will produce a warning
    return y_inner
end

outer_model = (
    p = nothing,
    fd = fd_outer,
    yd = yd_outer,
    Δt = 1 // 5,
    models = (inner_model = inner_model,),
)

simulate(outer_model, T = 10 // 1)

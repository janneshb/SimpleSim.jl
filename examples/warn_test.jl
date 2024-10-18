using SimpleSim

function fc_inner(x, u, p, t)
    return 0.5 * x
end

function gc_inner(x, u, p, t)
    return x
end

inner_model = (fc = fc_inner, gc = gc_inner, xc0 = 1.0)


function fd_outer(x, u, p, t; models)
    return nothing
end

function gd_outer(x, u, p, t; models)
    y_inner = @call! models.inner_model nothing # this is illegal and will produce a warning
    return y_inner
end

outer_model =
    (fd = fd_outer, gd = gd_outer, Δt = 1 // 5, models = (inner_model = inner_model,))

simulate(outer_model, T = 10 // 1)

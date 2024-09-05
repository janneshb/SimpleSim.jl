function init_working_copy(
    model;
    t0 = nothing,
    Δt = nothing,
    uc0 = nothing,
    ud0 = nothing,
    xc0 = nothing,
    xd0 = nothing,
    level = 0,
    recursive = false,
    structure_only = false,
    fieldname = "top-level model",
    integrator = RK4,
    T = nothing,
)
    function build_sub_tree(models::NamedTuple)
        return NamedTuple{keys(models)}((
            (
                init_working_copy(
                    m_i,
                    t0 = t0,
                    Δt = Δt,
                    uc0 = nothing,
                    ud0 = nothing;
                    level = level + 1,
                    recursive = true,
                    structure_only = structure_only,
                    fieldname = ".$fieldname_i",
                    T = T,
                ) for (m_i, fieldname_i) in zip(models, fieldnames(typeof(models)))
            )...,
        ))
    end

    function build_sub_tree(models::Tuple)
        return (
            (
                init_working_copy(
                    m_i,
                    t0 = t0,
                    Δt = Δt,
                    uc0 = nothing,
                    ud0 = nothing;
                    level = level + 1,
                    recursive = true,
                    structure_only = structure_only,
                    fieldname = "($fieldname_i)",
                    T = T,
                ) for (m_i, fieldname_i) in zip(models, fieldnames(typeof(models)))
            )...,
        )
    end

    function build_sub_tree(models::Vector)
        return [
            init_working_copy(
                m_i,
                t0 = t0,
                Δt = Δt,
                uc0 = nothing,
                ud0 = nothing;
                level = level + 1,
                recursive = true,
                structure_only = structure_only,
                fieldname = "[$i]",
                T = T,
            ) for (i, m_i) in enumerate(models)
        ]
    end

    model_name = "$fieldname / $(Base.typename(typeof(model)).wrapper)"
    global MODEL_COUNT = recursive ? MODEL_COUNT + 1 : 1
    model_id = MODEL_COUNT

    # TODO: add support for StaticArrays and better type inference
    DEBUG && level == 0 ? println("Initializing models at t = ", float(t0)) : nothing
    DEBUG && level == 0 ?
    println(
        "Top-level model is ",
        isCT(model) ? "CT." : (isDT(model) ? "DT." : "hybrid."),
    ) : nothing
    sub_tree = (;)
    if hasproperty(model, :models) && model.models !== nothing
        sub_tree = build_sub_tree(model.models)
    end

    rng_dt =
        hasproperty(model, :wd) &&
        hasproperty(model, :wd_seed) &&
        model.wd_seed !== nothing ? BASE_RNG(model.wd_seed) : BASE_RNG(model_id)

    xc0 =
        hasproperty(model, :xc0) && model.xc0 !== nothing ?
        (xc0 === nothing ? model.xc0 : xc0) : xc0
    uc0 =
        uc0 === nothing ?
        (hasproperty(model, :uc0) && model.uc0 !== nothing ? model.uc0 : nothing) : uc0
    ycs0 =
        !structure_only && hasproperty(model, :yc) && model.yc !== nothing ?
        (
            length(sub_tree) > 0 ? [model.yc(xc0, uc0, model.p, t0; models = sub_tree)] :
            [model.yc(xc0, uc0, model.p, t0)]
        ) : nothing

    xd0 =
        hasproperty(model, :xd0) && model.xd0 !== nothing ?
        (xd0 === nothing ? model.xd0 : xd0) : xd0
    ud0 =
        uc0 === nothing ?
        (hasproperty(model, :ud0) && model.ud0 !== nothing ? model.ud0 : nothing) : ud0
    wd0 = hasproperty(model, :wd) ? model.wd(xd0, ud0, model.p, t0, rng_dt) : nothing
    yd_kwargs = length(sub_tree) > 0 ? (models = sub_tree,) : ()
    yd_kwargs = hasproperty(model, :wd) ? (yd_kwargs..., w = wd0) : yd_kwargs
    yds0 =
        !structure_only && hasproperty(model, :yd) && model.yd !== nothing ?
        [model.yd(xd0, ud0, model.p, t0; yd_kwargs...)] : nothing

    type = begin
        temp_type = TypeUnknown::ModelType
        if isCT(model)
            temp_type = TypeCT::ModelType
        elseif isDT(model)
            temp_type = TypeDT::ModelType
        end
        if isHybrid(model)
            temp_type = TypeHybrid::ModelType
        end
        temp_type
    end

    return (
        name = model_name,
        model_id = model_id,
        type = type,
        callable_ct! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_ct!(u, t, model, model_working_copy, Δt, integrator, T) :
                       nothing,
        callable_dt! = !structure_only ?
                       (u, t, model_working_copy) ->
            model_callable_dt!(u, t, model, model_working_copy, T) : nothing,
        Δt = !structure_only && hasproperty(model, :Δt) && model.Δt !== nothing ? model.Δt :
             Δt,
        zero_crossing_tol = !structure_only &&
                            hasproperty(model, :zero_crossing_tol) &&
                            model.zero_crossing_tol !== nothing ? model.zero_crossing_tol :
                            ZERO_CROSSING_TOL,
        # the following store the latest state
        tcs = !structure_only && hasproperty(model, :yc) && model.yc !== nothing ? [t0] :
              nothing,
        xcs = !structure_only &&
              hasproperty(model, :fc) &&
              model.fc !== nothing &&
              xc0 !== nothing ? [xc0] : nothing,
        ycs = ycs0,
        tds = !structure_only && hasproperty(model, :yd) && model.yd !== nothing ? [t0] :
              nothing,
        xds = !structure_only &&
              hasproperty(model, :fd) &&
              model.fd !== nothing &&
              xd0 !== nothing ? [xd0] : nothing,
        yds = yds0,
        wds = !structure_only && hasproperty(model, :wd) ?
              [model.wd(xd0, ud0, model.p, t0, rng_dt)] : nothing,
        rng_dt = rng_dt,
        models = sub_tree,
    )
end

# adds an entry (tc, xc, yc) to the working copy of the model
function update_working_copy_ct!(model_working_copy, t, xc, yc, T)
    if t > T
        return
    end
    push!(model_working_copy.tcs, eltype(model_working_copy.tcs)(t)) # always store the time if the model was called
    try
        xc !== nothing ? push!(model_working_copy.xcs, eltype(model_working_copy.xcs)(xc)) :
        nothing
    catch
        @error "Could not update CT state evolution. Please check your state variables for type consistency"
    end
    try
        yc !== nothing ? push!(model_working_copy.ycs, eltype(model_working_copy.ycs)(yc)) :
        nothing
    catch
        @error "Could not update CT output evolution. Please check your output variables for type consistency"
    end
end

# adds an entry (td, xd, yd) to the working copy of the model
function update_working_copy_dt!(model_working_copy, t, xd, yd, wd, T)
    if t > T
        return
    end
    push!(model_working_copy.tds, eltype(model_working_copy.tds)(t)) # always store the time if the model was called
    try
        xd !== nothing ? push!(model_working_copy.xds, eltype(model_working_copy.xds)(xd)) :
        nothing
    catch
        @error "Could not update DT state evolution. Please check your state variables for type consistency"
    end
    try
        yd !== nothing ? push!(model_working_copy.yds, eltype(model_working_copy.yds)(yd)) :
        nothing
    catch
        @error "Could not update DT output evolution. Please check your output variables for type consistency"
    end
    try
        wd !== nothing ? push!(model_working_copy.wds, eltype(model_working_copy.wds)(wd)) :
        nothing
    catch
        @error "Could not update DT random draw evolution. Please check your random variables for type consistency"
    end
end

# reduce output and cast time series into matrix form
function post_process(out)
    function post_process_submodels(models::NamedTuple)
        return NamedTuple{keys(models)}(((post_process(m_i) for m_i in models)...,))
    end

    function post_process_submodels(models::Tuple)
        return ((post_process(m_i) for m_i in models)...,)
    end

    function post_process_submodels(models::Vector)
        return [post_process(m_i) for m_i in models]
    end

    return (
        model_id = out.model_id,
        Δt = hasproperty(out, :Δt) && out.Δt !== nothing ? out.Δt : Δt,
        tcs = out.tcs,
        xcs = out.xcs !== nothing ? reduce(vcat, transpose.(out.xcs)) : nothing,
        ycs = out.ycs !== nothing ? reduce(vcat, transpose.(out.ycs)) : nothing,
        tds = out.tds,
        xds = out.xds !== nothing ? reduce(vcat, transpose.(out.xds)) : nothing,
        yds = out.yds !== nothing ? reduce(vcat, transpose.(out.yds)) : nothing,
        wds = out.wds !== nothing ? reduce(vcat, transpose.(out.wds)) : nothing,
        models = post_process_submodels(out.models),
    )
end

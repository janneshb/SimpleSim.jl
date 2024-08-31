function due(model, t)
    # TODO: this can be simplified
    context = @context
    if isCT(model) && context == ContextCT::SimulationContext
        return model.tcs[end] < t # CT models can always be updated if time has progressed
    end
    if isDT(model) && context == ContextDT::SimulationContext
        return model.tds[end] + model.Δt <= t
    end
    if isHybrid(model)
        # TODO: this might not work as it's supposed to
        if context == ContextCT::SimulationContext
            return model.tcs[end] < t # CT models can always be updated if time has progressed
        elseif context == ContextDT::SimulationContext
            return model.tds[end] + model.Δt <= t
        else
            @error "Could not determine if the model is due to update."
        end
    end
    return false
end

function isCT(model)
    return (
        hasproperty(model, :fc) &&
        hasproperty(model, :yc) &&
        model.fc !== nothing &&
        model.yc !== nothing
    ) || (hasproperty(model, :type) && model.type == TypeCT::ModelType)
end

function isDT(model)
    return (
        hasproperty(model, :fd) &&
        hasproperty(model, :yd) &&
        hasproperty(model, :Δt) &&
        model.fd !== nothing &&
        model.yd !== nothing &&
        model.Δt !== nothing
    ) || (hasproperty(model, :type) && model.type == TypeDT::ModelType)
end

function isHybrid(model)
    return (
        (
            hasproperty(model, :fd) &&
            hasproperty(model, :fc) &&
            hasproperty(model, :yd) &&
            hasproperty(model, :yc) &&
            hasproperty(model, :Δt)
        ) && (
            model.fd !== nothing &&
            model.fc !== nothing &&
            model.yd !== nothing &&
            model.yc !== nothing &&
            model.Δt !== nothing
        )
    ) || (hasproperty(model, :type) && model.type == TypeHybrid::ModelType)
end

# finds the minimum step size across all models and submodels (recursively)
function find_min_Δt(model, Δt_prev, Δt_max)
    Δt = Δt_prev
    if hasproperty(model, :Δt) && model.Δt !== nothing
        Δt = gcd(Δt, check_rational(model.Δt))
    end

    if hasproperty(model, :models) && model.models !== nothing
        for m_i in model.models
            Δt = find_min_Δt(m_i, Δt, Δt_max)
        end
    end
    return gcd(Δt, check_rational(oneunit(Δt) * Δt_max))
end

export @out, @out_ct, @out_dt
"""
    @out model

Returns the current output of `model`. This macro is useful in `fc` or `fd` functions when access to a submodel's output is needed. The macro works similar to [`@state`](@ref).

# Example
```julia
function fc_parent_model(x, u, p, t; models)
    y_child = @out models[1]
    # ...
end
```

__Note:__ `@out` does not update the `model`. It only returns its current output. Use [`@call!`](@ref) to update submodels.
"""
macro out(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            !SILENT &&
                @error "@out is ambiguous for hybrid systems. Please specify using @out_ct or @out_dt."
        elseif isCT(model_to_call)
            @out_ct model_to_call
        elseif isDT(model_to_call)
            @out_dt model_to_call
        end
    end
end

"""
    @out_ct model

Returns the output of a given continuous-time model. Especially useful when retrieving the output of a hybrid model in which case `@out` would be ambiguous.
See [`@out`](@ref).
"""
macro out_ct(model)
    quote
        $(esc(model)).ycs[end]
    end
end

"""
    @out_dt model

Returns the output of a given discrete-time model. Especially useful when retrieving the output of a hybrid model in which case `@out` would be ambiguous.
See [`@out`](@ref).
"""
macro out_dt(model)
    quote
        $(esc(model)).yds[end]
    end
end

# Returns the latest state of a model without running it.
export @state, @state_ct, @state_dt
"""
    @state model

Returns the current state of `model`. This macro is useful in `fc` or `fd` functions when access to a submodel's state is needed. The macro works similar to [`@out`](@ref).

__Note:__ `@state` does not update the `model`. It only returns its current state. Use [`@call!`](@ref) to update submodels.

# Example
```julia
function fc_parent_model(x, u, p, t; models)
    x_child = @state models[1]
    # ...
end
```
"""
macro state(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            !SILENT &&
                @error "@state is ambiguous for hybrid systems. Please specify using @state_ct or @state_dt."
        elseif isCT(model_to_call)
            @state_ct model_to_call
        elseif isDT(model_to_call)
            @state_dt model_to_call
        end
    end
end

"""
    @state_ct model

Returns the state of a given contiuous-time model. Especially useful when retrieving the state of a hybrid model in which case `@state` would be ambiguous.
See [`@state`](@ref).
"""
macro state_ct(model)
    quote
        $(esc(model)).xcs[end]
    end
end

"""
    @state_dt model

Returns the state of a given discrete-time model. Especially useful when retrieving the state of a hybrid model in which case `@state` would be ambiguous.
See [`@state`](@ref).
"""
macro state_dt(model)
    quote
        $(esc(model)).xds[end]
    end
end

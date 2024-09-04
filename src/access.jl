export @out, @out_ct, @out_dt
"""
    @out

The out macro.
"""
macro out(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            @error "@out is ambiguous for hybrid systems. Please specify using @out_ct or @out_dt."
        elseif isCT(model_to_call)
            @out_ct model_to_call
        elseif isDT(model_to_call)
            @out_dt model_to_call
        end
    end
end

"""
    @out_ct

The CT out macro.
"""
macro out_ct(model)
    quote
        $(esc(model)).ycs[end]
    end
end

"""
    @out_dt

The DT out macro.
"""
macro out_dt(model)
    quote
        $(esc(model)).yds[end]
    end
end

# Returns the latest state of a model without running it.
export @state, @state_ct, @state_dt
"""
    @state

The state macro.
"""
macro state(model)
    quote
        model_to_call = $(esc(model))
        if isHybrid(model_to_call)
            @error "@state is ambiguous for hybrid systems. Please specify using @state_ct or @state_dt."
        elseif isCT(model_to_call)
            @state_ct model_to_call
        elseif isDT(model_to_call)
            @state_dt model_to_call
        end
    end
end

"""
    @state_ct

The CT state macro.
"""
macro state_ct(model)
    quote
        $(esc(model)).xcs[end]
    end
end

"""
    @state_dt

The DT state macro.
"""
macro state_dt(model)
    quote
        $(esc(model)).xds[end]
    end
end

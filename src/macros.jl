# @quiet macro disables DEBUG and DISABLE_PROGRESS output for the command given to it
macro quiet(command)
    quote
        exSILENT = SILENT
        global SILENT = true
        $(esc(command))
        global SILENT = exSILENT
    end
end

# @gather_default_config returns a NamedTuple with all variables that currently exist and their values
macro gather_default_config()
    accepted_types = [Number, Bool]
    exceptional_vars = [:BASE_RNG]

    default_config_names = ()
    default_config_vals = []
    global_vars = filter(
        x ->
            isdefined(SimpleSim, x) &&
                any([isa(getfield(SimpleSim, x), t) for t in accepted_types]) ||
                x in exceptional_vars,
        names(SimpleSim, all = true, imported = false),
    )
    for x in global_vars
        val = getfield(SimpleSim, x)
        default_config_names = (default_config_names..., x)
        push!(default_config_vals, val)
    end
    return NamedTuple{default_config_names}(default_config_vals)
end

# @set_options(options) tries to find global variables according to the keys in the NamedTuple `options` and sets them to the appropriate value.
macro set_options(options_nt)
    quote
        keys_original = Base.keys($(esc(options_nt)))
        keys = Symbol.(uppercase.(string.(keys_original)))
        vals = Base.values($(esc(options_nt)))
        for (i, (k, v)) in enumerate(zip(keys, vals))
            if isdefined(SimpleSim, k)
                eval(:(global $k = $v))
            end
        end
    end
end

# prints warnings for unsupported options
macro check_options(options_nt)
    quote
        keys_original = Base.keys($(esc(options_nt)))
        keys = Symbol.(uppercase.(string.(keys_original)))
        vals = Base.values($(esc(options_nt)))
        for (i, (k, v)) in enumerate(zip(keys, vals))
            if !isdefined(SimpleSim, k)
                !SILENT && @warn "Ignoring unsupported option $(keys_original[i])."
            end
        end
    end
end

# @safeguard_on / @safeguard_off are macros for internal use only to protect models from being called
macro safeguard_on()
    :(global MODEL_CALLS_DISABLED = true)
end
macro safeguard_off()
    :(global MODEL_CALLS_DISABLED = false)
end

# @ct / @dt switches the context to CT/DT
# @context returns the current context
macro ct()
    :(global CONTEXT = ContextCT::SimulationContext)
end
macro dt()
    :(global CONTEXT = ContextDT::SimulationContext)
end
macro call_completed()
    :(global CONTEXT = ContextUnknown::SimulationContext)
end
macro context()
    :(CONTEXT)
end

# @quiet macro disables DEBUG and DISABLE_PROGRESS output for the command given to it
macro quiet(command)
    quote
        exSILENT = SILENT
        global SILENT = true
        $(esc(command))
        global SILENT = exSILENT
    end
end

# @set_options(options) tries to find global variables according to the keys in the NamedTuple `options` and sets them to the appropriate value.
macro set_options(options_nt)
    quote
        keys_original = Base.keys($(esc(options_nt)))
        keys = Symbol.(uppercase.(string.(keys_original)))
        vals = Base.values($(esc(options_nt)))
        for (i, (k, v)) in enumerate(zip(keys, vals))
            if !isdefined(SimpleSim, k)
                !SILENT && @warn "Ignoring unsupported option $(keys_original[i])."
            else
                eval(:(global $k = $v))
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

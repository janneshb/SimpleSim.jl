# @quiet macro disables DEBUG and DISABLE_PROGRESS output for the command given to it
macro quiet(command)
    quote
        exDEBUG = DEBUG
        exDISPLAY_PROGRESS = DISPLAY_PROGRESS
        global DEBUG = false
        global DISPLAY_PROGRESS = false
        $(esc(command))
        global DEBUG = exDEBUG
        global DISPLAY_PROGRESS = exDISPLAY_PROGRESS
    end
end

# @set_option(key, value) tries to find a global variable with the same name as `key` and sets it to `val`.
macro set_option(key, val)
    var_name = string(key)
    global_var_name = uppercase(var_name)
    global_var_name_sym = Symbol(global_var_name)
    return quote
        if isdefined(Main, Symbol($global_var_name))
            global $global_var_name_sym = $val
        else
            !SILENT && @warn "Ignoring unsupported option `$($var_name)`."
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

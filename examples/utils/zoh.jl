macro zoh(t, X, Δt)
    quote
        DeltaT = $(esc(Δt))
        time = $(esc(t))
        data = $(esc(X))

        # make sure data and time belong together
        @assert size(time, 1) == size(data, 1)

        # create new time vector
        t_start = minimum(time)
        t_end = maximum(time)
        new_time = collect(t_start:DeltaT:t_end)

        # create empty data vector/matrix
        new_data = begin
            if isa(data, Vector)
                Vector{eltype(data)}(undef, length(new_time))
            elseif isa(data, Matrix)
                Matrix{eltype(data)}(undef, length(new_time), size(data)[2:end]...)
            else
                error("Unsupported data type. Only Vector and Matrix are supported.")
            end
        end

        # fill the new data matrix with ZOH data
        j = 1
        for i = 1:length(new_time)
            # Move to the next interval in the original time vector as needed
            while j < length(time) && new_time[i] >= time[j+1]
                global j += 1
            end
            # Assign the value from the original data vector
            new_data[i, :] = data[j, :]
        end
        (new_time, new_data)
    end
end

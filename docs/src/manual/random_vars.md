# Random Variables

For discrete-time systems, `SimpleSim.jl` can handle random variables for you.

If you want to use this feature, define a random draw function, and include it in your discrete-time model under the `wd` name.

```julia
function my_random_wd(x, u, p, t, rng)
    # ...
    return my_random_draw
end

my_system = (
    p = # ...
    Δt = # ...
    xd0 = # ...
    ud0 = # ...
    fd = # ...
    yd = # ...
    wd = my_random_wd,
)
```

The function `wd_random_draws` takes in the usual argument and a random number generator `rng`.
The random number generator can be used in the random draw function to generate any number of random draws using available techniques, e. g. the `Distributions` package.

Then, `SimpleSim.jl` passes the random draw to the `fd` and `yd` functions in the keyword argument `w`.

```julia
function my_fd(x, u, p, t; w)
    # ...
end

function my_yd(x, u, p, t; w)
    # ...
end
```

See the examples section for a "random walk" example.

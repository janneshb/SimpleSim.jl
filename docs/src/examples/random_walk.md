# Random Walk

This example implements a classical example from mathematics, where successive random steps are taken based on a given probability density function.

## Mathematics

In this example, a 2D walk is considered in which the "walker" can take a step forward, backward, left and right with certain probability.

The current position of the walker is denoted as $x$. On the xy-plane, "forward" is considered to be a step "up", i.e. in positive y-direction, and all other directions are chosen accordingly. Then, the position of the walker after taking a step, can be determined as follows

```math
x_+ = x + e
```

where $e$ is drawn from the following discrete distribution.

```math
E(X) = \begin{cases}
p_f & \text{if } X = [0, 1]^T\\
p_b & \text{if } X = [0, -1]^T\\
p_l & \text{if } X = [-1, 0]^T\\
p_r & \text{if } X = [1, 0]^T
\end{cases}
```

Note that $p_f + p_b + p_l + p_r = 1$ and that the walker cannot remain at its current position, i. e. $E([0, 0]) = 0$.

## Implementation

The random walk is implemented as a discrete-time dynamical system with a two-dimensional state.

### Setting up the Model

The dynamics of the system are straightforward to implement.

```julia
function fd_random_walk(x, u, p, t; w)
    return x + w
end

gd_random_walk = (x, u, p, t; w) -> x
```

The probabilities $p_i$ for the 4 state transitions are stored in the parameters `p`.

```julia
params = (
    p_f = 0.25,
    p_b = 0.25,
    p_l = 0.25,
    p_r = 0.25,
)
```

The random draw function itself can be implemented using the `rand()` function. It generates a random number between zero and one. The interval $[0, 1]$ is then partitioned into subintervals depending on the probabilities $p_i$.

```julia
function wd_random_walk(x, u, p, t, rng)
    r = rand(rng)
    if r < p.p_f
        return [0, 1]
    elseif r < p.p_f + p.p_b
        return [0, -1]
    elseif r < p.p_f + p.p_b + p_l
        return [-1, 0]
    else
        return[1, 0]
    end
end
```

The model then can be defined as follows

```julia
seed = 1234
random_walk_model = (
    p = params,
    fd = fd_random_walk,
    gd = gd_random_walk,
    wd = wd_random_walk,
    wd_seed = seed,
    xd0 = [0, 0],
    Δt = 1 // 1,
)
```

Note how the seed is passed to the model, not the simulation. Giving each model its own seed, ensures reproducibility of results as long as the `wd` function of the model does not change.

### Running the Simulation

The random walk model is simulated like any other model

```julia
N = 10
data = simulate(random_walk_model, T = N // 1)
```
where `N` is the number of steps taken by the walker.

### Results

The following animations show a random walk for `N = 10` and `N = 1000`.

```@raw html
<img src="../../assets/random_walk_animation_10.gif" style="width: 50%;" align="left">
<img src="../../assets/random_walk_animation_1000.gif" style="width: 50%;" align="right">
```

### Switching to a different RNG

If you want to use a different random number generator than `MersenneTwister`, you can pass it to `SimpleSim.jl` using the `options` keyword argument of `simulate`.

```julia
using Random
N = 10
data = simulate(random_walk_model,
    T = N // 1,
    options = (
        base_rng = Xoshiro,
    )
)
```

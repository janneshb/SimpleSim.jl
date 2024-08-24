using SimpleSim

function fd_random_draws(x, u, p, t; w)
    x = w
    return x
end

function yd_random_draws(x, u, p, t; w)
    return x
end

function wd_random_draws(x, u, p, t, rng)
    return p.μ + p.σ * rand(rng)
end

random_draws = (
    p = (μ = 0.0, σ = 1.0),
    Δt = 1 // 10,
    xd0 = 0.0,
    fd = fd_random_draws,
    yd = yd_random_draws,
    wd = wd_random_draws,
)

history = simulate(random_draws, T = 1//1) 

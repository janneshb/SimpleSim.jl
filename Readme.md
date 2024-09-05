# SimpleSim.jl

## TODO

- [x] Make sure the data is output as matrices and not a vector of vectors
- [x] Check support for vector submodels
- [ ] Write (proper) Julia tests
- [x] Implement random draw hook that is invariant to model structure
- [x] Zero-crossing detection / bouncing ball example
- [x] Finish implementing `RKF45` for three body problem.
- [ ] Implement `RKF45` for nested models
- [ ] Introduce simulation parameters storing things such as `Delta t_max`, `RKF45_REL_TOL` etc
- [ ] Implement `@log` macro for easy access to variables that aren't state or output
- [ ] Need better `@warn` and `@error`. Stuff is hard to debug at the moment
- [ ] Make parameters `p` optional (just pass `nothing`)
- [ ] Add init hook that can alter `p` and is called before the simulation runs
- [ ] Add terminate hook (for example to close opened files) that is run after simulation finishes
- [x] Break up the project into different files (e.g. the solvers and macros can have their own file)
- [x] Make public


<b>SimpleSim.jl</b> is a light-weight simulation package for dynamical systems simulation, controller synthesis and testing and robotics.

Run `import Pkg; Pkg.add("SimpleSim")` from within your Julia environment to install `SimpleSim.jl`.

## Examples

Multiple demos in the `exanmples/` provide a rough but incomplete overview of what `SimpleSim.jl` can do.


## Credit

A similar simulation architecture was proposed by [@tuckermcclure](https://www.github.com/tuckermcclure) in [overdot-sandbox](https://github.com/tuckermcclure/overdot-sandbox).

## Supported Hooks

```julia
p   # model parameters

fc  # continuous time dynamics hook x' = f(x)
yc  # continnous time output hook y = g(x)
uc0 # initial input (continuous time)
xc0 # initial value of the continuous time state

fd  # discrete time dynamics hook x_k+1 = f(x_k)
yd  # discrete time output hook y_k = g(x_k)
wd  # discrete random variable sampling
ud0 # initial input (discrete time)
xd0 # initial value of the discrete time state
```

## Arguments for simulate(...)

```julia
uc  # continuous time intput hook u = u(t)
ud  # discrete time input hook
```

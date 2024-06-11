# SimpleSim.jl

## TODO

- [x] Make sure the data is output as matrices and not a vector of vectors
- [x] Check support for vector submodels
- [ ] Write (proper) Julia tests
- [ ] Implement random draw hook that is invariant to model structure
- [ ] Make public


<b>SimpleSim.jl</b> is a light-weight simulation package for dynamical systems simulation, controller synthesis and testing and robotics.

Run `import Pkg; Pkg.add("SimpleSim")` from within your Julia environment to install `SimpleSim.jl`.

## Examples

Multiple demos in the `exanmples/` provide a rough but incomplete overview of what `SimpleSim.jl` can do.


## Credit



A similar simulation architecture was proposed by [@tuckermcclure](https://www.github.com/tuckermcclure) in [overdot-sandbox](https://github.com/tuckermcclure/overdot-sandbox).

## Supported Hooks

```
p   # model parameters

fc  # continuous time dynamics hook x' = f(x)
yc  # continnous time output hook y = g(x)
uc0 # initial input (continuous time)
xc0 # initial value of the continuous time state

fd  # discrete time dynamics hook x_k+1 = f(x_k)
yd  # discrete time output hook y_k = g(x_k)
ud0 # initial input (discrete time)
xd0 # initial value of the discrete time state
```

## Arguments for simulate(...)

```
uc  # continuous time intput hook u = u(t)
ud  # discrete time input hook
```

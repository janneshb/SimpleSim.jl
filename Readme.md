# SimpleSim.jl

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
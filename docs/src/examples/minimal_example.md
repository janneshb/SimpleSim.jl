# Minimal Example

This example simulates a falling object.
Its physics are governed by what probably is the simplest example of an ordinary differential equation.

```math
\ddot{x} = -g
```

We implement the object by defining a system of first-order differential equations

```math
\dot{z}_1 = z_2\\
\dot{z}_2 = -g
```

and implement the system in a `fc` function as follows

```julia
fc_falling_object = (z, u, p, t) -> [z[2], -p.g]
```

The gravitational constant is stored in the model as a parameter.
The output of our system will simply be the current position of the object, i. e. $z_1$.

```julia
gc_falling_object = (z, u, p, t) -> z[1]
```

Now, the whole model can be written as

```julia
falling_object = (
    p = (g = 9.81,),
    fc = fc_falling_object,
    gc = gc_falling_object,
)
```

Which can be simulated as
```julia
data = simulate(falling_object, T = 3 // 1, xc0 = [0, 0])
```

Done! This is the most minimal example I could think of, essentially being made up of four lines of code!

The position of the object (double integral of $-g$) can now be accessed using `data.ycs`.

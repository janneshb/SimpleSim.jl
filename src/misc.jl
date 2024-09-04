printI = "│"
printT = '├'
printLine = '─'
printL = "└"
printSpace = " "

export print_model_tree
"""
    print_model_tree(model)

Prints a _tree_ of the given model similar to a folder tree printed by the Linux `tree` command.

An example for a feedback-controlled inverted pendulum could look like this
```
julia> print_model_tree(my_model)
└─1 (TypeCT): top-level model / FeedbackSystem
  ├─2 (TypeCT): .inverted_pendulum / NamedTuple
  └─3 (TypeCT): .controller / NamedTuple
```

First, the `model_id` is indicated, following the type (`TypeCT`, `TypeDT` or `TypeHybrid`).
Then follows the name of each model in the super model.
This is either its field name in the `NamedTuple` passed as `models` or the index in the case of vectors or tuples.
Finally, after the slash, the type of each model is indicated. This should either be the name of a `struct` type, or `NamedTuple`.
"""
function print_model_tree(model)
    function print_model(
        model,
        depth;
        last = false,
        prev_groups_closed = [true for _ = 1:depth],
    )
        for i = 1:depth
            if prev_groups_closed[i]
                print(printSpace * printSpace)
            else
                print(printI * printSpace)
            end
        end
        !last ? print(printT) : print(printL)
        print(printLine)
        println("$(model.model_id) ($(model.type)): $(model.name) ")
    end

    @quiet working_copy = init_working_copy(model, structure_only = true)

    # print depth first / slightly adjusted FIFO to maintain order of models
    stack = Any[working_copy]
    depth_stack = Int[0]
    prev_groups_closed = Bool[]
    while !isempty(stack)
        node = popfirst!(stack)
        node_depth = popfirst!(depth_stack)
        last = isempty(stack) || depth_stack[1] != node_depth

        print_model(node, node_depth, last = last, prev_groups_closed = prev_groups_closed)

        pushfirst!(stack, node.models...)
        pushfirst!(depth_stack, [node_depth + 1 for i = 1:length(node.models)]...)

        if !isempty(depth_stack)
            depth_stack[1] > node_depth && push!(prev_groups_closed, last) # prepare to loop over submodels
            if depth_stack[1] < node_depth
                for _ = 1:(node_depth-depth_stack[1])
                    pop!(prev_groups_closed)
                end
            end
        end
    end
    return nothing
end

printI = "│"
printT = '├'
printLine = '─'
printL = "└"
printSpace = " "

export model_tree, print_model_tree
function model_tree(model)
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

    # print depth first / FIFO
    stack = Any[working_copy]
    depth_stack = Int[0]
    prev_groups_closed = []
    while !isempty(stack)
        node = pop!(stack)
        node_depth = pop!(depth_stack)
        last = isempty(stack) || depth_stack[1] != node_depth ? true : false

        print_model(node, node_depth, last = last, prev_groups_closed = prev_groups_closed)

        length(node.models) > 0 ? push!(prev_groups_closed, last) :
        (last && length(prev_groups_closed) > 0 ? pop!(prev_groups_closed) : nothing)
        for child in node.models
            pushfirst!(depth_stack, node_depth + 1)
            pushfirst!(stack, child)
        end
    end
    return nothing
end
const print_model_tree = model_tree

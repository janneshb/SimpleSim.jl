export analyze_model
"""
    analyze_model(model)

This function checks if a model has all necessary mandatory fields
and analyzes which optional fields are present.
"""
# TODO: finish analyzing the model
function analyze_model(model)
    model_is_ct = isCT(model)
    model_is_dt = isCT(model)
    model_is_hybrid = isCT(model)

    if !model_is_ct && !model_is_dt && !model_is_hybrid
        println("The given model is not valid.")
    end
end

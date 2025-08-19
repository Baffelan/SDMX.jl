"""
Julia-idiomatic Pipeline Operators for SDMX.jl

This module defines custom operators and pipeline functions for smooth workflow chaining,
leveraging Julia's operator overloading and method dispatch capabilities.
"""

using DataFrames
using Base.Threads

export ⊆, ⇒, validate_with, profile_with, map_with, generate_with, chain

# =================== CUSTOM OPERATORS ===================

"""
    ⊆(data::DataFrame, schema::DataflowSchema) -> Bool
    data ⊆ schema

Schema compliance operator using subset symbol. Returns true if data structure is a subset/compliant with schema requirements.

# Example
```julia
is_compliant = my_data ⊆ schema
if my_data ⊆ schema
    println("Data is schema compliant!")
end
```
"""
function ⊆(data::DataFrame, schema::DataflowSchema)
    required_cols = get_required_columns(schema)
    return all(col -> col in names(data), required_cols)
end

"""
    ⇒(data::DataFrame, validator::SDMXValidator) -> ValidationResult
    data ⇒ validator

Data flow operator: validate DataFrame directly.

# Example
```julia
result = my_data ⇒ validator
```
"""
function ⇒(data::DataFrame, validator::SDMXValidator)
    return validator(data)
end

# =================== PIPELINE FUNCTIONS ===================

"""
    validate_with(schema::DataflowSchema; kwargs...) -> Function

Creates a validation function that can be used in pipelines.

# Example
```julia
result = my_data |> validate_with(schema; strict_mode=true)
```
"""
function validate_with(schema::DataflowSchema; kwargs...)
    validator = create_validator(schema; kwargs...)
    return data -> validator(data)
end

"""
    profile_with(filename::String="data") -> Function

Creates a profiling function that can be used in pipelines.

# Example
```julia
profile = my_data |> profile_with("my_dataset.csv")
```
"""
function profile_with(filename::String="data")
    return data -> profile_source_data(data, filename)
end

# =================== WORKFLOW CHAINING FUNCTIONS ===================

"""
    chain(operations...) -> Function

Creates a composable chain of operations that can be applied to data.

# Example
```julia
processor = chain(
    validate_with(schema),
    profile_with("my_data.csv"),
    data -> (data, map_with(engine, schema)(profile_source_data(data, "temp")))
)

result = my_data |> processor
```
"""
function chain(operations...)
    return data -> foldl((result, op) -> op(result), operations, init=data)
end

# =================== EXTENDED PIPELINE OPERATORS ===================
# Note: DataSource-related pipeline operators moved to SDMXLLM.jl package

# =================== COMPREHENSIVE WORKFLOW PIPELINE ===================

"""
    SDMXPipeline

A composable pipeline for complete SDMX data processing workflows.
"""
struct SDMXPipeline{T}
    operations::T
end

"""
    pipeline(operations...) -> SDMXPipeline

Create an SDMX processing pipeline with chainable operations.

# Example
```julia
my_pipeline = pipeline(
    validate_with(schema; strict_mode=true),
    profile_with("dataset.csv"),
    mapping_stage -> (mapping_stage, infer_advanced_mappings(engine, mapping_stage, schema)),
    generate_with(generator, schema; template_name="standard_transformation")
)

# Execute the pipeline
result = my_data |> my_pipeline
```
"""
function pipeline(operations...)
    return SDMXPipeline(operations)
end

"""
    |>(data, pipeline::SDMXPipeline)

Execute an SDMXPipeline on data.
"""
function |>(data, pipeline::SDMXPipeline)
    return foldl((result, op) -> op(result), pipeline.operations, init=data)
end

# =================== SPECIALIZED DATA FLOW OPERATORS ===================

# This function was moved above to use ⇒ instead

# =================== UTILITY PIPELINE FUNCTIONS ===================

"""
    tap(f::Function) -> Function

Creates a "tap" function for side effects in pipelines (like logging, printing, etc.)
without modifying the data flow.

# Example
```julia
result = my_data |>
    tap(d -> println("Processing \$(nrow(d)) rows")) |>
    validate_with(schema) |>
    tap(r -> println("Validation score: \$(r.overall_score)"))
```
"""
function tap(f::Function)
    return data -> begin
        f(data)
        return data
    end
end

"""
    branch(condition::Function, true_path::Function, false_path::Function=identity) -> Function

Creates conditional branching in pipelines.

# Example
```julia
result = my_data |>
    branch(
        data -> nrow(data) > 1000,
        validate_with(schema; performance_mode=true),  # Large dataset path
        validate_with(schema; strict_mode=true)        # Small dataset path
    )
```
"""
function branch(condition::Function, true_path::Function, false_path::Function=identity)
    return data -> condition(data) ? true_path(data) : false_path(data)
end

"""
    parallel_map(f::Function, collections...) -> Function

Creates a parallel mapping function for use in pipelines.
Useful for processing multiple datasets or performing multiple operations concurrently.

# Example
```julia
# Process multiple datasets in parallel
results = datasets |> parallel_map(validate_with(schema))
```
"""
function parallel_map(f::Function)
    return collections -> begin
        results = Vector{Any}(undef, length(collections))
        @threads for i in 1:length(collections)
            results[i] = f(collections[i])
        end
        return results
    end
end
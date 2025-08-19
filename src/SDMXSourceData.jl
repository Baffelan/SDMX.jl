"""
Source data ingestion and profiling for SDMX.jl

This module handles reading and analyzing source data files (CSV, Excel) to:
- Detect column types and data patterns
- Profile data quality and completeness
- Identify potential categorical variables and their values
- Detect time/date columns and formats
- Analyze data distributions for mapping suggestions
"""

using DataFrames, CSV, XLSX, Statistics, Dates
using EzXML, HTTP

export SourceDataProfile, read_source_data, profile_source_data, suggest_column_mappings

"""
    ColumnProfile

A struct containing detailed information about a single column in source data.

Fields:
- `name::String`: Original column name
- `type::Type`: Detected Julia type
- `missing_count::Int`: Number of missing values
- `unique_count::Int`: Number of unique values
- `sample_values::Vector`: Sample of actual values (up to 10)
- `is_categorical::Bool`: Whether this appears to be a categorical variable
- `categories::Union{Vector, Nothing}`: Unique categories if categorical
- `is_temporal::Bool`: Whether this appears to be a time/date column
- `temporal_format::Union{String, Nothing}`: Detected date/time format
- `numeric_stats::Union{NamedTuple, Nothing}`: Min/max/mean if numeric
- `string_patterns::Vector{String}`: Common string patterns if text
"""
struct ColumnProfile
    name::String
    type::Type
    missing_count::Int
    unique_count::Int
    sample_values::Vector
    is_categorical::Bool
    categories::Union{Vector, Nothing}
    is_temporal::Bool
    temporal_format::Union{String, Nothing}
    numeric_stats::Union{NamedTuple, Nothing}
    string_patterns::Vector{String}
end

"""
    SourceDataProfile

A struct containing comprehensive analysis of source data.

Fields:
- `file_path::String`: Path to the source file
- `file_type::String`: File type (csv, xlsx, etc.)
- `row_count::Int`: Number of data rows
- `column_count::Int`: Number of columns
- `columns::Vector{ColumnProfile}`: Detailed profile of each column
- `data_quality_score::Float64`: Overall data quality score (0-1)
- `suggested_key_columns::Vector{String}`: Columns that might be dimensions
- `suggested_value_columns::Vector{String}`: Columns that might be measures
- `suggested_time_columns::Vector{String}`: Columns that might be time dimensions
"""
struct SourceDataProfile
    file_path::String
    file_type::String
    row_count::Int
    column_count::Int
    columns::Vector{ColumnProfile}
    data_quality_score::Float64
    suggested_key_columns::Vector{String}
    suggested_value_columns::Vector{String}
    suggested_time_columns::Vector{String}
end

"""
    read_source_data(file_path::String; sheet=1, header_row=1) -> DataFrame

Reads data from CSV or Excel files with automatic format detection.

# Arguments
- `file_path::String`: Path to the data file
- `sheet=1`: Excel sheet number or name (ignored for CSV)
- `header_row=1`: Row number containing column headers

# Returns
- `DataFrame`: The loaded data
"""
function read_source_data(file_path::String; sheet=1, header_row=1)
    if !isfile(file_path)
        error("File not found: $file_path")
    end
    
    file_ext = lowercase(splitext(file_path)[2])
    
    if file_ext == ".csv"
        return CSV.read(file_path, DataFrame)
    elseif file_ext in [".xlsx", ".xls"]
        return XLSX.readtable(file_path, sheet; first_row=header_row) |> DataFrame
    else
        error("Unsupported file format: $file_ext. Supported formats: .csv, .xlsx, .xls")
    end
end

"""
    detect_column_type_and_patterns(column_data::Vector) -> NamedTuple

Analyzes a column to detect its type, patterns, and characteristics.
"""
function detect_column_type_and_patterns(column_data::Vector)
    # Remove missing values for analysis
    non_missing_data = filter(!ismissing, column_data)
    
    if isempty(non_missing_data)
        return (
            type = Missing,
            is_categorical = false,
            categories = nothing,
            is_temporal = false,
            temporal_format = nothing,
            numeric_stats = nothing,
            string_patterns = String[]
        )
    end
    
    # Detect the primary type
    types = unique(typeof.(non_missing_data))
    primary_type = length(types) == 1 ? types[1] : Any
    
    # Check if numeric
    is_numeric = all(x -> isa(x, Number), non_missing_data)
    numeric_stats = nothing
    if is_numeric && !isempty(non_missing_data)
        numeric_vals = collect(non_missing_data)
        numeric_stats = (
            min = minimum(numeric_vals),
            max = maximum(numeric_vals),
            mean = mean(numeric_vals),
            median = median(numeric_vals)
        )
    end
    
    # Check if temporal
    is_temporal = false
    temporal_format = nothing
    if all(x -> isa(x, Union{Date, DateTime, Time}), non_missing_data)
        is_temporal = true
        temporal_format = "Julia_DateTime"
    elseif primary_type == String
        # Try to detect date patterns in strings
        date_patterns = [
            r"^\d{4}-\d{2}-\d{2}$" => "YYYY-MM-DD",
            r"^\d{2}/\d{2}/\d{4}$" => "MM/DD/YYYY",
            r"^\d{4}$" => "YYYY",
            r"^\d{4}-\d{2}$" => "YYYY-MM",
            r"^\d{4}Q[1-4]$" => "YYYY-Q"
        ]
        
        for (pattern, format) in date_patterns
            if length(non_missing_data) > 0 && all(x -> occursin(pattern, string(x)), non_missing_data[1:min(5, length(non_missing_data))])
                is_temporal = true
                temporal_format = format
                break
            end
        end
    elseif is_numeric && primary_type <: Integer
        # Check if numeric values look like years
        if length(non_missing_data) > 0
            min_val = minimum(non_missing_data)
            max_val = maximum(non_missing_data)
            # Consider as years if integers in reasonable year range
            if 1900 <= min_val <= 2100 && 1900 <= max_val <= 2100
                is_temporal = true
                temporal_format = "YYYY"
            end
        end
    end
    
    # Check if categorical
    unique_vals = unique(non_missing_data)
    unique_count = length(unique_vals)
    total_count = length(non_missing_data)
    
    # Improved categorical detection logic:
    # 1. If numeric and all values are unique (or nearly unique), not categorical
    # 2. If numeric and reasonable number of repeats, might be categorical codes
    # 3. If string-based, use the original thresholds
    uniqueness_ratio = unique_count / total_count
    
    if is_numeric
        # For numeric data, be more strict about categorization
        # Only consider categorical if there are clear repeated values
        is_categorical = unique_count < 10 && uniqueness_ratio < 0.8
    else
        # For non-numeric data, use the original logic
        is_categorical = unique_count < 20 || (uniqueness_ratio < 0.5 && unique_count < 100)
    end
    
    categories = is_categorical ? unique_vals : nothing
    
    # Extract string patterns
    string_patterns = String[]
    if primary_type == String && length(non_missing_data) > 0
        # Sample a few values to identify patterns
        sample_strings = string.(non_missing_data[1:min(10, length(non_missing_data))])
        patterns = Set{String}()
        
        for s in sample_strings
            # Simple pattern detection
            if occursin(r"^[A-Z]{2,3}$", s)
                push!(patterns, "UPPERCASE_CODE")
            elseif occursin(r"^\d+$", s)
                push!(patterns, "NUMERIC_STRING")
            elseif occursin(r"^[A-Za-z\s]+$", s)
                push!(patterns, "TEXT_NAME")
            elseif occursin(r"^\w+_\w+", s)
                push!(patterns, "UNDERSCORE_SEPARATED")
            end
        end
        string_patterns = collect(patterns)
    end
    
    return (
        type = primary_type,
        is_categorical = is_categorical,
        categories = categories,
        is_temporal = is_temporal,
        temporal_format = temporal_format,
        numeric_stats = numeric_stats,
        string_patterns = string_patterns
    )
end

"""
    profile_column(name::String, data::Vector) -> ColumnProfile

Creates a detailed profile for a single column.
"""
function profile_column(name::String, data::Vector)
    missing_count = count(ismissing, data)
    non_missing_data = filter(!ismissing, data)
    unique_count = length(unique(non_missing_data))
    
    # Get sample values
    sample_size = min(10, length(non_missing_data))
    sample_values = sample_size > 0 ? non_missing_data[1:sample_size] : []
    
    # Detect patterns and types
    analysis = detect_column_type_and_patterns(data)
    
    return ColumnProfile(
        name,
        analysis.type,
        missing_count,
        unique_count,
        sample_values,
        analysis.is_categorical,
        analysis.categories,
        analysis.is_temporal,
        analysis.temporal_format,
        analysis.numeric_stats,
        analysis.string_patterns
    )
end

"""
    profile_source_data(df::DataFrame, file_path::String = "") -> SourceDataProfile

Creates a comprehensive profile of source data including column analysis and mapping suggestions.
"""
function profile_source_data(df::DataFrame, file_path::String = "")
    row_count = nrow(df)
    column_count = ncol(df)
    
    # Profile each column (convert to Vector to handle PooledArrays)
    columns = [profile_column(string(col), collect(df[!, col])) for col in names(df)]
    
    # Calculate data quality score
    total_cells = row_count * column_count
    total_missing = sum(col.missing_count for col in columns)
    data_quality_score = total_cells > 0 ? 1.0 - (total_missing / total_cells) : 0.0
    
    # Suggest column roles based on analysis
    suggested_key_columns = String[]
    suggested_value_columns = String[]
    suggested_time_columns = String[]
    
    for col in columns
        col_name = col.name
        
        # Time dimension candidates
        if col.is_temporal
            push!(suggested_time_columns, col_name)
        end
        
        # Dimension candidates (categorical with reasonable cardinality)
        if col.is_categorical && col.unique_count > 1 && col.unique_count < 1000
            push!(suggested_key_columns, col_name)
        end
        
        # Measure candidates (numeric, not categorical)
        if col.numeric_stats !== nothing && !col.is_categorical
            push!(suggested_value_columns, col_name)
        end
    end
    
    # Determine file type
    file_type = if !isempty(file_path)
        lowercase(splitext(file_path)[2])[2:end]  # Remove the dot
    else
        "unknown"
    end
    
    return SourceDataProfile(
        file_path,
        file_type,
        row_count,
        column_count,
        columns,
        data_quality_score,
        suggested_key_columns,
        suggested_value_columns,
        suggested_time_columns
    )
end

"""
    suggest_column_mappings(source_profile::SourceDataProfile, target_schema::DataflowSchema) -> Dict{String, Vector{String}}

Suggests mappings between source data columns and SDMX schema elements based on:
- Column name similarity
- Data type compatibility
- Value pattern matching
- Statistical properties

Returns a dictionary mapping SDMX column names to potential source column matches, ranked by confidence.
"""
function suggest_column_mappings(source_profile::SourceDataProfile, target_schema::DataflowSchema)
    mappings = Dict{String, Vector{String}}()
    
    # Get all target columns
    all_dimensions = target_schema.dimensions.dimension_id
    time_dim = target_schema.time_dimension !== nothing ? [target_schema.time_dimension.dimension_id] : String[]
    all_measures = target_schema.measures.measure_id
    all_attributes = target_schema.attributes.attribute_id
    
    # Helper function to calculate name similarity
    function name_similarity(source_name::String, target_name::String)
        source_lower = lowercase(source_name)
        target_lower = lowercase(target_name)
        
        # Exact match
        if source_lower == target_lower
            return 1.0
        end
        
        # Substring match
        if occursin(target_lower, source_lower) || occursin(source_lower, target_lower)
            return 0.8
        end
        
        # Common patterns
        similarities = [
            ("time", "period", "date", "year", "month", "quarter") => time_dim,
            ("geo", "country", "region", "location", "area") => filter(x -> occursin("geo", lowercase(x)), all_dimensions),
            ("sex", "gender") => filter(x -> occursin("sex", lowercase(x)), all_dimensions),
            ("age") => filter(x -> occursin("age", lowercase(x)), all_dimensions),
            ("value", "amount", "count", "rate", "percent") => all_measures
        ]
        
        for (keywords, target_cols) in similarities
            if any(keyword -> occursin(keyword, source_lower), keywords) && target_name in target_cols
                return 0.6
            end
        end
        
        return 0.0
    end
    
    # Map time dimensions first
    for time_col in time_dim
        candidates = String[]
        for source_col in source_profile.columns
            if source_col.is_temporal
                score = name_similarity(source_col.name, time_col)
                if score > 0.3 || source_col.is_temporal
                    push!(candidates, source_col.name)
                end
            end
        end
        if !isempty(candidates)
            mappings[time_col] = candidates
        end
    end
    
    # Map dimensions
    for dim_col in all_dimensions
        candidates = Tuple{String, Float64}[]
        
        for source_col in source_profile.columns
            score = name_similarity(source_col.name, dim_col)
            
            # Boost score if categorical and reasonable cardinality
            if source_col.is_categorical && 2 <= source_col.unique_count <= 500
                score += 0.3
            end
            
            # Penalty for too many unique values (likely not a dimension)
            if source_col.unique_count > 1000
                score *= 0.3
            end
            
            if score > 0.2
                push!(candidates, (source_col.name, score))
            end
        end
        
        # Sort by score and keep top candidates
        sort!(candidates, by=x->x[2], rev=true)
        if !isempty(candidates)
            mappings[dim_col] = [c[1] for c in candidates[1:min(3, length(candidates))]]
        end
    end
    
    # Map measures
    for measure_col in all_measures
        candidates = Tuple{String, Float64}[]
        
        for source_col in source_profile.columns
            score = name_similarity(source_col.name, measure_col)
            
            # Boost score if numeric
            if source_col.numeric_stats !== nothing
                score += 0.4
            end
            
            # Penalty if categorical (likely not a measure)
            if source_col.is_categorical
                score *= 0.5
            end
            
            if score > 0.2
                push!(candidates, (source_col.name, score))
            end
        end
        
        # Sort by score
        sort!(candidates, by=x->x[2], rev=true)
        if !isempty(candidates)
            mappings[measure_col] = [c[1] for c in candidates[1:min(3, length(candidates))]]
        end
    end
    
    # Map attributes (lower priority, only high-confidence matches)
    for attr_col in all_attributes
        candidates = String[]
        
        for source_col in source_profile.columns
            score = name_similarity(source_col.name, attr_col)
            if score > 0.7  # High threshold for attributes
                push!(candidates, source_col.name)
            end
        end
        
        if !isempty(candidates)
            mappings[attr_col] = candidates
        end
    end
    
    return mappings
end

"""
    print_source_profile(profile::SourceDataProfile)

Prints a human-readable summary of the source data profile.
"""
function print_source_profile(profile::SourceDataProfile)
    println("=== Source Data Profile ===")
    println("File: $(profile.file_path)")
    println("Type: $(profile.file_type)")
    println("Dimensions: $(profile.row_count) rows × $(profile.column_count) columns")
    println("Data Quality Score: $(round(profile.data_quality_score * 100, digits=1))%")
    
    println("\n--- Column Analysis ---")
    for col in profile.columns
        println("$(col.name):")
        println("  Type: $(col.type)")
        println("  Missing: $(col.missing_count) ($(round(col.missing_count/length(profile.columns) * 100, digits=1))%)")
        println("  Unique values: $(col.unique_count)")
        
        if col.is_temporal
            println("  → Time/Date column ($(col.temporal_format))")
        elseif col.is_categorical
            println("  → Categorical ($(min(5, length(col.categories))) categories shown): $(col.categories[1:min(5, length(col.categories))])")
        elseif col.numeric_stats !== nothing
            println("  → Numeric ($(col.numeric_stats.min) - $(col.numeric_stats.max), mean: $(round(col.numeric_stats.mean, digits=2)))")
        end
        println()
    end
    
    println("--- Mapping Suggestions ---")
    println("Time columns: $(profile.suggested_time_columns)")
    println("Key/Dimension columns: $(profile.suggested_key_columns)")
    println("Value/Measure columns: $(profile.suggested_value_columns)")
end
"""
SDMX Data Query Functions for SDMX.jl

This module provides functional approaches to construct and execute SDMX data queries,
retrieving actual statistical data (as opposed to structural metadata).

Features:
- Simple functions to build SDMX data query URLs for any provider
- Fetch data in SDMX-CSV format using DataFrames
- Support for dimension filtering and time ranges
- Works with any SDMX provider and dataflow
"""

using DataFrames, CSV, HTTP, Statistics

export construct_data_url, fetch_sdmx_data, query_sdmx_data, construct_sdmx_key

"""
    construct_sdmx_key(schema::DataflowSchema, filters::Dict{String,String}) -> String

Constructs a proper SDMX key using the dataflow schema to determine dimension order.
Validates that filter dimensions exist in the schema.

# Arguments
- `schema`: DataflowSchema containing dimension definitions and order
- `filters`: Dict mapping dimension names to filter values

# Examples
```julia
# Get schema first
xml_doc = read_sdmx_structure(url)
schema = extract_dataflow_schema(xml_doc)

# Construct key with validation
filters = Dict("FREQ" => "A", "GEO_PICT" => "TO")
key = construct_sdmx_key(schema, filters)
# Returns proper SDMX key based on schema dimension order
```
"""
function construct_sdmx_key(schema::DataflowSchema, filters::Dict{String,String})
    # Get dimension order from schema
    # This needs to be implemented in the schema extraction functions
    dimension_order = get_dimension_order(schema)
    
    # Validate that all filter dimensions exist in schema
    schema_dimensions = Set(dimension_order)
    for dim in keys(filters)
        if !(dim in schema_dimensions)
            throw(ArgumentError("Dimension '$dim' not found in dataflow schema. Available dimensions: $(join(dimension_order, ", "))"))
        end
    end
    
    # Construct key with proper dot notation
    key_parts = String[]
    for dim in dimension_order
        value = get(filters, dim, "")  # Empty string for unfiltered dimensions
        push!(key_parts, value)
    end
    
    return join(key_parts, ".")
end


"""
    construct_data_url(base_url::String, agency_id::String, dataflow_id::String, version::String;
                      key::String="",
                      dimension_filters::Dict{String,String}=Dict{String,String}(),
                      start_period::Union{String,Nothing}=nothing,
                      end_period::Union{String,Nothing}=nothing,
                      dimension_at_observation::String="AllDimensions") -> String

Constructs an SDMX data query URL using functional parameters.

# Arguments
- `base_url`: SDMX REST API base URL  
- `agency_id`: Data provider agency (e.g., "SPC", "ECB", "OECD")
- `dataflow_id`: Dataflow identifier (e.g., "DF_BP50", "EXR", "QNA")
- `version`: Dataflow version (e.g., "1.0" or "latest")
- `key`: Pre-constructed key string (if provided, dimension_filters ignored)
- `dimension_filters`: Dict mapping dimension names to values
- `start_period`, `end_period`: Time range filters
- `dimension_at_observation`: How to structure response

# Examples
```julia
# Using pre-constructed key (most flexible)
url = construct_data_url(
    "https://stats-sdmx-disseminate.pacificdata.org/rest",
    "SPC", "DF_BP50", "1.0",
    key="A.TO.BX_TRF_PWKR._T._T._T._T._T._T._T....",
    start_period="2022"
)

# Using dimension filters (automatically builds key)
url = construct_data_url(
    "https://sdw-wsrest.ecb.europa.eu/service",
    "ECB", "EXR", "1.0", 
    dimension_filters=Dict("FREQ" => "D", "CURRENCY" => "USD"),
    start_period="2023-01"
)

# Simple case - let SDMX provider handle defaults
url = construct_data_url(
    "https://stats-sdmx-disseminate.pacificdata.org/rest",
    "SPC", "DF_BP50", "1.0",
    start_period="2022"
)
```
"""
function construct_data_url(base_url::String, agency_id::String, dataflow_id::String, version::String;
                           schema::Union{DataflowSchema,Nothing}=nothing,
                           key::String="",
                           dimension_filters::Dict{String,String}=Dict{String,String}(),
                           start_period::Union{String,Nothing}=nothing,
                           end_period::Union{String,Nothing}=nothing,
                           dimension_at_observation::String="AllDimensions")
    
    # Build dataflow reference
    dataflow_ref = "$agency_id,$dataflow_id,$version"
    
    # Use provided key or construct from filters and schema
    final_key = if !isempty(key)
        key
    elseif !isempty(dimension_filters) && schema !== nothing
        construct_sdmx_key(schema, dimension_filters)
    elseif !isempty(dimension_filters)
        @warn "Dimension filters provided without schema - key construction may be incorrect"
        join(values(dimension_filters), ".")  # Fallback - join values
    else
        ""  # Empty key - get all data
    end
    
    # Build URL
    url = "$base_url/data/$dataflow_ref/$final_key"
    
    # Add query parameters
    params = String[]
    start_period !== nothing && push!(params, "startPeriod=$start_period")
    end_period !== nothing && push!(params, "endPeriod=$end_period")
    push!(params, "dimensionAtObservation=$dimension_at_observation")
    
    !isempty(params) && (url *= "?" * join(params, "&"))
    
    return url
end

"""
    fetch_sdmx_data(url::String; timeout::Int=30) -> DataFrame

Fetches SDMX data in CSV format from any SDMX provider and returns a cleaned DataFrame.

# Examples
```julia
# Pacific Data Hub
url = construct_data_url("https://stats-sdmx-disseminate.pacificdata.org/rest", 
                        "SPC", "DF_BP50", "1.0", start_period="2022")
data = fetch_sdmx_data(url)

# ECB exchange rates
url = construct_data_url("https://sdw-wsrest.ecb.europa.eu/service",
                        "ECB", "EXR", "1.0", 
                        dimension_filters=Dict("FREQ" => "D", "CURRENCY" => "USD"))
data = fetch_sdmx_data(url)
```
"""
function fetch_sdmx_data(url::String; timeout::Int=30)
    # Set SDMX-CSV headers
    headers = Dict(
        "Accept" => "application/vnd.sdmx.data+csv;version=2.0.0",
        "User-Agent" => "SDMX.jl/0.1.0"
    )
    
    try
        response = HTTP.get(url; headers=headers, timeout=timeout)
        
        response.status == 200 || throw(ArgumentError("HTTP $(response.status): Failed to fetch data"))
        
        csv_content = String(response.body)
        isempty(strip(csv_content)) && return DataFrame()  # Empty response
        
        # Parse CSV and clean data
        data = CSV.read(IOBuffer(csv_content), DataFrame)
        return clean_sdmx_data(data)
        
    catch e
        isa(e, HTTP.StatusError) ? 
            throw(ArgumentError("SDMX API error $(e.status): $(String(e.response.body))")) :
            throw(ArgumentError("Failed to fetch SDMX data: $e"))
    end
end

"""
    clean_sdmx_data(data::DataFrame) -> DataFrame

Performs basic cleaning and type conversion on SDMX-CSV data.
Works with any SDMX provider's CSV format.
"""
function clean_sdmx_data(data::DataFrame)
    isempty(data) && return data
    
    # Create a copy to avoid mutations
    cleaned = copy(data)
    
    # Convert OBS_VALUE to numeric (standard SDMX column)
    if hasproperty(cleaned, :OBS_VALUE)
        cleaned.OBS_VALUE = map(cleaned.OBS_VALUE) do val
            ismissing(val) || val == "" ? missing :
            isa(val, Number) ? Float64(val) :
            tryparse(Float64, string(val))
        end
    end
    
    # Ensure TIME_PERIOD is string (standard SDMX column)
    if hasproperty(cleaned, :TIME_PERIOD)
        cleaned.TIME_PERIOD = string.(cleaned.TIME_PERIOD)
    end
    
    # Remove completely empty rows
    if nrow(cleaned) > 0
        non_empty_mask = map(eachrow(cleaned)) do row
            !all(ismissing, row)
        end
        cleaned = cleaned[non_empty_mask, :]
    end
    
    return cleaned
end

"""
    query_sdmx_data(base_url::String, agency_id::String, dataflow_id::String, version::String="latest";
                    key::String="",
                    dimension_filters::Dict{String,String}=Dict{String,String}(),
                    start_period::Union{String,Nothing}=nothing,
                    end_period::Union{String,Nothing}=nothing) -> DataFrame

Convenience function to query SDMX data from any provider in a single call.

# Examples
```julia
# Pacific Data Hub - all Tonga data since 2022
data = query_sdmx_data(
    "https://stats-sdmx-disseminate.pacificdata.org/rest",
    "SPC", "DF_BP50", "1.0",
    dimension_filters=Dict("GEO_PICT" => "TO"),
    start_period="2022"
)

# ECB - EUR/USD daily exchange rates
data = query_sdmx_data(
    "https://sdw-wsrest.ecb.europa.eu/service",
    "ECB", "EXR", "1.0",
    dimension_filters=Dict("FREQ" => "D", "CURRENCY" => "USD", "CURRENCY_DENOM" => "EUR"),
    start_period="2024-01-01"
)

# OECD - using pre-constructed key
data = query_sdmx_data(
    "https://stats.oecd.org/restsdmx/sdmx.ashx",
    "OECD", "QNA", "1.0",
    key="AUS.GDP.CPC.Y.L",  # Australia, GDP, Current prices, Yearly, Levels
    start_period="2020"
)
```
"""
function query_sdmx_data(base_url::String, agency_id::String, dataflow_id::String, version::String="latest";
                        key::String="",
                        dimension_filters::Dict{String,String}=Dict{String,String}(),
                        start_period::Union{String,Nothing}=nothing,
                        end_period::Union{String,Nothing}=nothing)
    
    url = construct_data_url(base_url, agency_id, dataflow_id, version,
                           key=key,
                           dimension_filters=dimension_filters,
                           start_period=start_period, 
                           end_period=end_period)
    
    return fetch_sdmx_data(url)
end

"""
    summarize_data(data::DataFrame) -> Dict{String, Any}

Provides a functional summary of SDMX data from any provider.
"""
function summarize_data(data::DataFrame)
    isempty(data) && return Dict("total_observations" => 0)
    
    summary = Dict{String, Any}("total_observations" => nrow(data))
    
    # Time range (standard SDMX)
    if hasproperty(data, :TIME_PERIOD)
        periods = sort(unique(skipmissing(data.TIME_PERIOD)))
        !isempty(periods) && (summary["time_range"] = (first(periods), last(periods)))
    end
    
    # Observation statistics (standard SDMX)
    if hasproperty(data, :OBS_VALUE)
        valid_obs = filter(!ismissing, data.OBS_VALUE)
        if !isempty(valid_obs)
            summary["obs_stats"] = (
                count=length(valid_obs),
                min=minimum(valid_obs), 
                max=maximum(valid_obs),
                mean=round(mean(valid_obs), digits=2)
            )
        end
    end
    
    # Generic dimension summary - detect common SDMX dimensions
    common_dimensions = ["FREQ", "INDICATOR", "GEO_PICT", "REF_AREA", "CURRENCY", "SUBJECT"]
    for dim in common_dimensions
        if hasproperty(data, Symbol(dim))
            values = sort(unique(skipmissing(data[!, dim])))
            !isempty(values) && (summary[lowercase(dim)] = values)
        end
    end
    
    return summary
end
"""
SDMX Availability Constraint extraction for SDMX.jl

This module extracts actual data availability information from SDMX availability constraints,
showing which dimension values actually have published data (vs. theoretical schema possibilities).

Key differences from dataflow schema:
- Schema: Shows ALL possible/allowed dimension values
- Availability: Shows ONLY dimension values that have actual data

Features:
- Extract available time periods (actual date ranges with data)
- Get available codelist values (countries, indicators, etc. with data)  
- Observation counts and data coverage metrics
- Time range analysis for data gaps
- Integration with dataflow schema for completeness analysis
"""

using EzXML, DataFrames, HTTP, Dates

"""
    TimeAvailability

Structure containing comprehensive information about actual time period coverage in SDMX datasets.

This struct captures detailed temporal availability information from SDMX availability
constraints, including date ranges, format specifications, period counts, and data gaps
to provide complete temporal coverage analysis.

# Fields
- `start_date::Union{Date, String}`: Earliest available time period in the dataset
- `end_date::Union{Date, String}`: Latest available time period in the dataset
- `format::String`: Time period format ("date", "year", "quarter", "month", etc.)
- `total_periods::Int`: Total number of distinct time periods with data
- `gaps::Vector{String}`: Missing time periods within the overall range

# Examples
```julia
# Create time availability information
time_availability = TimeAvailability(
    Date("2020-01-01"),
    Date("2023-12-31"),
    "year", 
    4,
    ["2021"]
)

# Access coverage information
println("Data available from: ", time_availability.start_date)
println("Data available to: ", time_availability.end_date)
println("Total periods: ", time_availability.total_periods)

# Check for gaps
if !isempty(time_availability.gaps)
    println("Missing periods: ", join(time_availability.gaps, ", "))
end
```

# See also
[`AvailabilityConstraint`](@ref), [`extract_availability`](@ref), [`get_time_coverage`](@ref)
"""
struct TimeAvailability
    start_date::Union{Date, String}
    end_date::Union{Date, String}
    format::String  # "date", "year", "quarter", etc.
    total_periods::Int
    gaps::Vector{String}  # Missing periods within the range
end

"""
    DimensionAvailability

Availability information for a single dimension.
"""
struct DimensionAvailability
    dimension_id::String
    available_values::Vector{String}
    total_count::Int
    value_type::String  # "codelist", "time", "free_text"
    coverage_ratio::Float64  # available / theoretical (if schema provided)
end

"""
    AvailabilityConstraint

Complete availability constraint information from SDMX.
"""
struct AvailabilityConstraint
    constraint_id::String
    constraint_name::String
    agency_id::String
    version::String
    dataflow_ref::NamedTuple  # Reference to the dataflow
    total_observations::Int
    dimensions::Vector{DimensionAvailability}
    time_coverage::Union{TimeAvailability, Nothing}
    extraction_timestamp::String
end

"""
    extract_availability(url::String) -> AvailabilityConstraint

Extracts availability constraint information from an SDMX availability URL.

# Example
```julia
# For Pacific Data Hub
availability = extract_availability("https://stats-sdmx-disseminate.pacificdata.org/rest/availableconstraint/DF_DISABILITY/")
```
"""
function extract_availability(input::String)
    # Use the robust URL handling from SDMXHelpers
    xml_content = fetch_sdmx_xml(input)
    doc = EzXML.parsexml(xml_content)
    return extract_availability(doc)
end

"""
    extract_availability(doc::EzXML.Document) -> AvailabilityConstraint

Extracts availability constraint information from a parsed XML document.
"""
function extract_availability(doc::EzXML.Document)
    # Register common SDMX namespaces to handle different XML structures
    doc_root = root(doc)
    
    # Try different namespace patterns for ContentConstraint
    constraint_node = findfirst("//structure:ContentConstraint", doc_root)
    if constraint_node === nothing
        constraint_node = findfirst("//str:ContentConstraint", doc_root)
    end
    if constraint_node === nothing  
        constraint_node = findfirst("//ContentConstraint", doc_root)
    end
    if constraint_node === nothing
        # Try without namespace prefix
        constraint_nodes = findall("//*[local-name()='ContentConstraint']", doc_root)
        if !isempty(constraint_nodes)
            constraint_node = constraint_nodes[1]
        end
    end
    
    if constraint_node === nothing
        all_elements = [nodename(n) for n in findall("//*", doc_root)]
        sample_elements = all_elements[1:min(10, length(all_elements))]
        separator = ", "
        throw(ArgumentError("No ContentConstraint found in the document. Available elements: $(join(sample_elements, separator))"))
    end
    
    # Extract basic constraint info
    constraint_id = haskey(constraint_node, "id") ? constraint_node["id"] : "unknown"
    agency_id = haskey(constraint_node, "agencyID") ? constraint_node["agencyID"] : "unknown" 
    version = haskey(constraint_node, "version") ? constraint_node["version"] : "1.0"
    
    # Get constraint name (namespace-agnostic)
    name_node = findfirst(".//*[local-name()='Name']", constraint_node)
    constraint_name = name_node !== nothing ? strip(name_node.content) : "Availability Constraint"
    
    # Get observation count from annotations (namespace-agnostic)
    obs_count_node = findfirst(".//*[local-name()='Annotation'][@id='obs_count']/*[local-name()='AnnotationTitle']", constraint_node)
    total_observations = if obs_count_node !== nothing
        content = strip(obs_count_node.content)
        if occursin(r"^\d+$", content)  # Check if it's all digits
            parse(Int, content)
        else
            @warn "Invalid observation count format: '$content', defaulting to 0"
            0
        end
    else
        0
    end
    
    # Get dataflow reference (namespace-agnostic)
    dataflow_ref_node = findfirst(".//*[local-name()='Dataflow']/*[local-name()='Ref']", constraint_node)
    dataflow_ref = if dataflow_ref_node !== nothing
        (
            id = haskey(dataflow_ref_node, "id") ? dataflow_ref_node["id"] : "unknown",
            agency = haskey(dataflow_ref_node, "agencyID") ? dataflow_ref_node["agencyID"] : "unknown",
            version = haskey(dataflow_ref_node, "version") ? dataflow_ref_node["version"] : "1.0"
        )
    else
        (id="unknown", agency="unknown", version="1.0")
    end
    
    # Extract dimension availability from CubeRegion (namespace-agnostic)
    cube_region = findfirst(".//*[local-name()='CubeRegion']", constraint_node)
    dimensions = Vector{DimensionAvailability}()
    time_coverage = nothing
    
    if cube_region !== nothing
        key_values = findall(".//*[local-name()='KeyValue']", cube_region)
        
        for kv_node in key_values
            dim_id = kv_node["id"]
            
            # Handle time dimension specially
            if dim_id == "TIME_PERIOD"
                time_coverage = extract_time_availability(kv_node)
                # Also add as regular dimension
                time_values = get_time_period_values(kv_node)
                push!(dimensions, DimensionAvailability(
                    dim_id,
                    time_values,
                    length(time_values),
                    "time",
                    1.0  # Can't calculate coverage without schema
                ))
            else
                # Regular dimension
                values = extract_dimension_values(kv_node)
                push!(dimensions, DimensionAvailability(
                    dim_id,
                    values,
                    length(values),
                    "codelist",  # Assume codelist for non-time dimensions
                    1.0  # Can't calculate coverage without schema
                ))
            end
        end
    end
    
    return AvailabilityConstraint(
        constraint_id,
        constraint_name,
        agency_id,
        version,
        dataflow_ref,
        total_observations,
        dimensions,
        time_coverage,
        string(Dates.now())
    )
end

"""
    extract_time_availability(time_node::EzXML.Node) -> TimeAvailability

Extracts time coverage information from a TIME_PERIOD KeyValue node.
"""
function extract_time_availability(time_node::EzXML.Node)
    # Check for TimeRange (namespace-agnostic)
    time_range = findfirst(".//*[local-name()='TimeRange']", time_node)
    
    if time_range !== nothing
        start_node = findfirst(".//*[local-name()='StartPeriod']", time_range)
        end_node = findfirst(".//*[local-name()='EndPeriod']", time_range)
        
        start_date = start_node !== nothing ? strip(start_node.content) : ""
        end_date = end_node !== nothing ? strip(end_node.content) : ""
        
        # Parse as dates with validation
        start_parsed = if length(start_date) >= 10 && occursin(r"^\d{4}-\d{2}-\d{2}", start_date)
            Date(start_date[1:10])  # Take just YYYY-MM-DD part
        else
            start_date  # Keep as string if not valid date format
        end
        
        end_parsed = if length(end_date) >= 10 && occursin(r"^\d{4}-\d{2}-\d{2}", end_date)
            Date(end_date[1:10])
        else
            end_date  # Keep as string if not valid date format
        end
        
        # Calculate total periods (rough estimate for years)
        total_periods = if start_parsed isa Date && end_parsed isa Date
            year(end_parsed) - year(start_parsed) + 1
        else
            1
        end
        
        return TimeAvailability(
            start_parsed,
            end_parsed,
            "date",
            total_periods,
            String[]  # Would need additional analysis to find gaps
        )
    else
        # Discrete time values
        time_values = extract_dimension_values(time_node)
        return TimeAvailability(
            length(time_values) > 0 ? time_values[1] : "",
            length(time_values) > 0 ? time_values[end] : "",
            "discrete",
            length(time_values),
            String[]
        )
    end
end

"""
    get_time_period_values(time_node::EzXML.Node) -> Vector{String}

Gets time period values as strings for dimension analysis.
"""
function get_time_period_values(time_node::EzXML.Node)
    # Check for TimeRange first (namespace-agnostic)
    time_range = findfirst(".//*[local-name()='TimeRange']", time_node)
    
    if time_range !== nothing
        start_node = findfirst(".//*[local-name()='StartPeriod']", time_range)
        end_node = findfirst(".//*[local-name()='EndPeriod']", time_range)
        
        start_str = start_node !== nothing ? strip(start_node.content) : ""
        end_str = end_node !== nothing ? strip(end_node.content) : ""
        
        # For ranges, return start-end representation
        if !isempty(start_str) && !isempty(end_str)
            return ["$(start_str[1:4])-$(end_str[1:4])"]  # Year range
        end
    end
    
    # Fall back to discrete values
    return extract_dimension_values(time_node)
end

"""
    extract_dimension_values(kv_node::EzXML.Node) -> Vector{String}

Extracts all available values for a dimension from a KeyValue node.
"""
function extract_dimension_values(kv_node::EzXML.Node)
    values = String[]
    value_nodes = findall(".//*[local-name()='Value']", kv_node)
    
    for value_node in value_nodes
        push!(values, strip(value_node.content))
    end
    
    return sort(values)  # Return sorted for consistency
end

"""
    get_available_values(availability::AvailabilityConstraint, dimension_id::String) -> Vector{String}

Gets available values for a specific dimension.

# Example
```julia
countries = get_available_values(availability, "GEO_PICT")
indicators = get_available_values(availability, "INDICATOR")
```
"""
function get_available_values(availability::AvailabilityConstraint, dimension_id::String)
    dim_index = findfirst(d -> d.dimension_id == dimension_id, availability.dimensions)
    return dim_index !== nothing ? availability.dimensions[dim_index].available_values : String[]
end

"""
    get_time_coverage(availability::AvailabilityConstraint) -> Union{TimeAvailability, Nothing}

Gets time coverage information if available.
"""
function get_time_coverage(availability::AvailabilityConstraint)
    return availability.time_coverage
end

"""
    compare_schema_availability(schema::DataflowSchema, availability::AvailabilityConstraint) -> Dict{String, Any}

Compares theoretical schema possibilities with actual data availability.

Returns coverage ratios, missing values, and data gaps analysis.
"""
function compare_schema_availability(schema::DataflowSchema, availability::AvailabilityConstraint)
    comparison = Dict{String, Any}()
    
    # Get codelist information from schema
    schema_codelists = get_codelist_columns(schema)
    
    coverage_summary = Dict{String, Any}()
    missing_analysis = Dict{String, Vector{String}}()
    
    for dim_avail in availability.dimensions
        dim_id = dim_avail.dimension_id
        available_values = Set(dim_avail.available_values)
        
        if haskey(schema_codelists, dim_id)
            # This dimension has a codelist in the schema
            # We would need to fetch the full codelist to compare
            # For now, just record what we have
            coverage_summary[dim_id] = Dict(
                "available_count" => length(available_values),
                "available_values" => sort(collect(available_values)),
                "note" => "Full schema comparison requires codelist fetch"
            )
        else
            # Dimension without codelist (free text or time)
            coverage_summary[dim_id] = Dict(
                "available_count" => length(available_values),
                "available_values" => sort(collect(available_values)),
                "type" => "non_codelist"
            )
        end
    end
    
    comparison["coverage_by_dimension"] = coverage_summary
    comparison["total_observations"] = availability.total_observations
    comparison["dataflow_match"] = availability.dataflow_ref.id == schema.dataflow_info.id
    
    # Time coverage analysis
    if availability.time_coverage !== nothing
        time_info = availability.time_coverage
        comparison["time_coverage"] = Dict(
            "start" => time_info.start_date,
            "end" => time_info.end_date,
            "total_periods" => time_info.total_periods,
            "format" => time_info.format
        )
    end
    
    return comparison
end

"""
    get_data_coverage_summary(availability::AvailabilityConstraint) -> DataFrame

Creates a summary DataFrame of data coverage by dimension.
"""
function get_data_coverage_summary(availability::AvailabilityConstraint)
    rows = []
    
    for dim in availability.dimensions
        push!(rows, (
            dimension_id = dim.dimension_id,
            available_values = dim.total_count,
            sample_values = join(dim.available_values[1:min(5, length(dim.available_values))], ", "),
            value_type = dim.value_type
        ))
    end
    
    df = DataFrame(rows)
    
    # Add summary row
    push!(df, (
        dimension_id = "TOTAL_OBSERVATIONS",
        available_values = availability.total_observations,
        sample_values = "N/A",
        value_type = "count"
    ))
    
    return df
end

"""
    find_data_gaps(availability::AvailabilityConstraint, expected_values::Dict{String, Vector{String}}) -> Dict{String, Vector{String}}

Identifies missing values by comparing availability with expected values.

# Arguments
- `availability`: The availability constraint
- `expected_values`: Dict mapping dimension_id to expected value lists

# Returns
Dict mapping dimension_id to missing values
"""
function find_data_gaps(availability::AvailabilityConstraint, expected_values::Dict{String, Vector{String}})
    gaps = Dict{String, Vector{String}}()
    
    for (dim_id, expected_list) in expected_values
        available_values = get_available_values(availability, dim_id)
        available_set = Set(available_values)
        expected_set = Set(expected_list)
        
        missing_values = collect(setdiff(expected_set, available_set))
        if !isempty(missing_values)
            gaps[dim_id] = sort(missing_values)
        end
    end
    
    return gaps
end

"""
    print_availability_summary(availability::AvailabilityConstraint)

Prints a human-readable summary of the availability constraint.
"""
function print_availability_summary(availability::AvailabilityConstraint)
    println("=== SDMX Availability Summary ===")
    println("Constraint: $(availability.constraint_name)")
    println("Dataflow: $(availability.dataflow_ref.agency):$(availability.dataflow_ref.id)")
    println("Total Observations: $(availability.total_observations)")
    
    if availability.time_coverage !== nothing
        time_info = availability.time_coverage
        println("Time Coverage: $(time_info.start_date) to $(time_info.end_date)")
    end
    
    println("\nDimension Coverage:")
    for dim in availability.dimensions
        sample_values = join(dim.available_values[1:min(3, length(dim.available_values))], ", ")
        more_text = length(dim.available_values) > 3 ? " (and $(length(dim.available_values) - 3) more)" : ""
        println("  $(dim.dimension_id): $(dim.total_count) values - $sample_values$more_text")
    end
    
    println("Extracted: $(availability.extraction_timestamp)")
end
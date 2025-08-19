"""
Dataflow structure extraction functions for SDMX.jl

This module extracts complete dataflow schema information including:
- Dataflow metadata (name, description, agency, version)
- Data Structure Definition (DSD) with dimensions, attributes, and measures
- Position ordering, data types, and codelist references
- Required vs conditional attribute assignments
"""

using EzXML, DataFrames, HTTP

export extract_dataflow_schema

"""
    DataflowSchema

A struct containing the complete schema information for an SDMX dataflow.

Fields:
- `dataflow_info::NamedTuple`: Basic dataflow metadata (id, agency, version, name, description)
- `dimensions::DataFrame`: All dimensions with position, concept, codelist info
- `attributes::DataFrame`: All attributes with assignment status, concept, codelist info  
- `measures::DataFrame`: Primary measure(s) with concept and data type info
- `time_dimension::Union{NamedTuple, Nothing}`: Special time dimension info if present
"""
struct DataflowSchema
    dataflow_info::NamedTuple
    dimensions::DataFrame
    attributes::DataFrame
    measures::DataFrame
    time_dimension::Union{NamedTuple, Nothing}
end

"""
    extract_dimension_info(dim_node::EzXML.Node) -> NamedTuple

Extracts information from a single Dimension or TimeDimension node.
"""
function extract_dimension_info(dim_node::EzXML.Node)
    dim_id = dim_node["id"]
    position = parse(Int, dim_node["position"])
    
    # Get concept reference
    concept_ref = findfirst(".//structure:ConceptIdentity/Ref", dim_node)
    concept_id = concept_ref !== nothing ? concept_ref["id"] : missing
    concept_scheme = concept_ref !== nothing && haskey(concept_ref, "maintainableParentID") ? concept_ref["maintainableParentID"] : missing
    
    # Get codelist reference (if enumeration)
    codelist_ref = findfirst(".//structure:LocalRepresentation/structure:Enumeration/Ref", dim_node)
    codelist_id = codelist_ref !== nothing ? codelist_ref["id"] : missing
    codelist_agency = codelist_ref !== nothing ? codelist_ref["agencyID"] : missing
    codelist_version = codelist_ref !== nothing ? codelist_ref["version"] : missing
    
    # Get text format (if non-enumerated)
    text_format = findfirst(".//structure:LocalRepresentation/structure:TextFormat", dim_node)
    data_type = text_format !== nothing && haskey(text_format, "textType") ? text_format["textType"] : missing
    
    # Determine if this is a time dimension
    is_time_dimension = nodename(dim_node) == "TimeDimension"
    
    return (
        dimension_id = dim_id,
        position = position,
        concept_id = concept_id,
        concept_scheme = concept_scheme,
        codelist_id = codelist_id,
        codelist_agency = codelist_agency,
        codelist_version = codelist_version,
        data_type = data_type,
        is_time_dimension = is_time_dimension
    )
end

"""
    extract_attribute_info(attr_node::EzXML.Node) -> NamedTuple

Extracts information from a single Attribute node.
"""
function extract_attribute_info(attr_node::EzXML.Node)
    attr_id = attr_node["id"]
    assignment_status = haskey(attr_node, "assignmentStatus") ? attr_node["assignmentStatus"] : "Mandatory"
    
    # Get concept reference
    concept_ref = findfirst(".//structure:ConceptIdentity/Ref", attr_node)
    concept_id = concept_ref !== nothing ? concept_ref["id"] : missing
    concept_scheme = concept_ref !== nothing && haskey(concept_ref, "maintainableParentID") ? concept_ref["maintainableParentID"] : missing
    
    # Get codelist reference (if enumeration)
    codelist_ref = findfirst(".//structure:LocalRepresentation/structure:Enumeration/Ref", attr_node)
    codelist_id = codelist_ref !== nothing ? codelist_ref["id"] : missing
    codelist_agency = codelist_ref !== nothing ? codelist_ref["agencyID"] : missing
    codelist_version = codelist_ref !== nothing ? codelist_ref["version"] : missing
    
    # Get text format (if non-enumerated)
    text_format = findfirst(".//structure:LocalRepresentation/structure:TextFormat", attr_node)
    data_type = text_format !== nothing && haskey(text_format, "textType") ? text_format["textType"] : missing
    
    # Get attribute relationship (what it attaches to)
    relationship = "Dataset"  # default
    if findfirst(".//structure:AttributeRelationship/structure:PrimaryMeasure", attr_node) !== nothing
        relationship = "Observation"
    elseif findfirst(".//structure:AttributeRelationship/structure:Dimension", attr_node) !== nothing
        relationship = "Dimension"
    end
    
    return (
        attribute_id = attr_id,
        assignment_status = assignment_status,
        concept_id = concept_id,
        concept_scheme = concept_scheme,
        codelist_id = codelist_id,
        codelist_agency = codelist_agency,
        codelist_version = codelist_version,
        data_type = data_type,
        relationship = relationship
    )
end

"""
    extract_measure_info(measure_node::EzXML.Node) -> NamedTuple

Extracts information from a PrimaryMeasure node.
"""
function extract_measure_info(measure_node::EzXML.Node)
    measure_id = measure_node["id"]
    
    # Get concept reference
    concept_ref = findfirst(".//structure:ConceptIdentity/Ref", measure_node)
    concept_id = concept_ref !== nothing ? concept_ref["id"] : missing
    concept_scheme = concept_ref !== nothing && haskey(concept_ref, "maintainableParentID") ? concept_ref["maintainableParentID"] : missing
    
    # Get text format
    text_format = findfirst(".//structure:LocalRepresentation/structure:TextFormat", measure_node)
    data_type = text_format !== nothing && haskey(text_format, "textType") ? text_format["textType"] : "Double"
    
    return (
        measure_id = measure_id,
        concept_id = concept_id,
        concept_scheme = concept_scheme,
        data_type = data_type
    )
end

"""
    extract_dataflow_schema(doc::EzXML.Document) -> DataflowSchema

Extracts complete dataflow schema information from an SDMX structure document.

# Arguments
- `doc::EzXML.Document`: The parsed SDMX XML document.

# Returns
- `DataflowSchema`: A comprehensive schema object with all dataflow structure information.
"""
function extract_dataflow_schema(doc::EzXML.Document)
    rootnode = root(doc)
    
    # Extract dataflow basic information
    dataflow_node = findfirst("//structure:Dataflow", rootnode)
    if dataflow_node === nothing
        error("No dataflow found in document")
    end
    
    dataflow_info = (
        id = dataflow_node["id"],
        agency = dataflow_node["agencyID"],
        version = dataflow_node["version"],
        name = begin
            name_node = findfirst(".//common:Name[@xml:lang='en']", dataflow_node)
            name_node !== nothing ? nodecontent(name_node) : missing
        end,
        description = begin
            desc_node = findfirst(".//common:Description[@xml:lang='en']", dataflow_node)
            desc_node !== nothing ? nodecontent(desc_node) : missing
        end,
        dsd_id = begin
            dsd_ref = findfirst(".//structure:Structure/Ref", dataflow_node)
            dsd_ref !== nothing ? dsd_ref["id"] : missing
        end
    )
    
    # Find the corresponding Data Structure Definition
    dsd_node = findfirst("//structure:DataStructure[@id='$(dataflow_info.dsd_id)']", rootnode)
    if dsd_node === nothing
        error("Data Structure Definition '$(dataflow_info.dsd_id)' not found")
    end
    
    # Extract dimensions
    dimension_nodes = findall(".//structure:DimensionList/structure:Dimension", dsd_node)
    time_dim_nodes = findall(".//structure:DimensionList/structure:TimeDimension", dsd_node)
    
    all_dim_nodes = vcat(dimension_nodes, time_dim_nodes)
    dimension_data = [extract_dimension_info(node) for node in all_dim_nodes]
    
    # Separate time dimension if present
    time_dimension = nothing
    regular_dimensions = dimension_data
    if !isempty(time_dim_nodes)
        time_dims = filter(d -> d.is_time_dimension, dimension_data)
        if !isempty(time_dims)
            time_dimension = time_dims[1]
            regular_dimensions = filter(d -> !d.is_time_dimension, dimension_data)
        end
    end
    
    dimensions_df = DataFrame(regular_dimensions)
    
    # Extract attributes
    attribute_nodes = findall(".//structure:AttributeList/structure:Attribute", dsd_node)
    attribute_data = [extract_attribute_info(node) for node in attribute_nodes]
    attributes_df = DataFrame(attribute_data)
    
    # Extract measures
    measure_nodes = findall(".//structure:MeasureList/structure:PrimaryMeasure", dsd_node)
    measure_data = [extract_measure_info(node) for node in measure_nodes]
    measures_df = DataFrame(measure_data)
    
    return DataflowSchema(dataflow_info, dimensions_df, attributes_df, measures_df, time_dimension)
end

"""
    extract_dataflow_schema(input::String) -> DataflowSchema

Convenience wrapper to download dataflow schema from a URL or parse from XML string.
This function automatically detects whether the string is a URL or XML content.
"""
function extract_dataflow_schema(input::String)
    try
        # Use the robust URL handling from SDMXHelpers
        xml_string = fetch_sdmx_xml(input)
        doc = parsexml(xml_string)
        return extract_dataflow_schema(doc)
    catch e
        println("Error during HTTP request or parsing: ", e)
        rethrow(e)
    end
end

"""
    get_required_columns(schema::DataflowSchema) -> Vector{String}

Returns a vector of column names that are required for SDMX-CSV output.
This includes all dimensions, the primary measure, and mandatory attributes.
"""
function get_required_columns(schema::DataflowSchema)
    required_cols = String[]
    
    # All dimensions are required
    append!(required_cols, schema.dimensions.dimension_id)
    
    # Time dimension if present
    if schema.time_dimension !== nothing
        push!(required_cols, schema.time_dimension.dimension_id)
    end
    
    # Primary measure is required
    append!(required_cols, schema.measures.measure_id)
    
    # Mandatory attributes
    mandatory_attrs = filter(row -> row.assignment_status == "Mandatory", schema.attributes)
    append!(required_cols, mandatory_attrs.attribute_id)
    
    return required_cols
end

"""
    get_optional_columns(schema::DataflowSchema) -> Vector{String}

Returns a vector of column names that are optional for SDMX-CSV output.
This includes conditional attributes.
"""
function get_optional_columns(schema::DataflowSchema)
    optional_attrs = filter(row -> row.assignment_status == "Conditional", schema.attributes)
    return collect(optional_attrs.attribute_id)
end

"""
    get_codelist_columns(schema::DataflowSchema) -> Dict{String, NamedTuple}

Returns a dictionary mapping column names to their codelist information.
Only includes columns that have associated codelists.
"""
function get_codelist_columns(schema::DataflowSchema)
    codelist_cols = Dict{String, NamedTuple}()
    
    # Check dimensions
    for row in eachrow(schema.dimensions)
        if !ismissing(row.codelist_id)
            codelist_cols[row.dimension_id] = (
                codelist_id = row.codelist_id,
                agency = row.codelist_agency,
                version = row.codelist_version
            )
        end
    end
    
    # Check attributes
    for row in eachrow(schema.attributes)
        if !ismissing(row.codelist_id)
            codelist_cols[row.attribute_id] = (
                codelist_id = row.codelist_id,
                agency = row.codelist_agency,
                version = row.codelist_version
            )
        end
    end
    
    return codelist_cols
end

"""
    get_dimension_order(schema::DataflowSchema) -> Vector{String}

Returns the ordered list of dimension IDs for constructing SDMX data query keys.
Dimensions are ordered by their position, with the time dimension (if present) included.
"""
function get_dimension_order(schema::DataflowSchema)
    # Sort dimensions by position
    sorted_dims = sort(schema.dimensions, :position)
    dimension_ids = collect(sorted_dims.dimension_id)
    
    # Add time dimension if present (usually comes last but check position)
    if schema.time_dimension !== nothing
        # Insert time dimension at correct position if it has one
        if haskey(schema.time_dimension, :position)
            # Find correct insertion point
            time_pos = schema.time_dimension.position
            insert_idx = findlast(d -> d <= time_pos, sorted_dims.position)
            if insert_idx === nothing
                insert!(dimension_ids, 1, schema.time_dimension.dimension_id)
            else
                insert!(dimension_ids, insert_idx + 1, schema.time_dimension.dimension_id)
            end
        else
            # Default to end if no position specified
            push!(dimension_ids, schema.time_dimension.dimension_id)
        end
    end
    
    return dimension_ids
end
"""
Concept extraction functions for SDMX.jl
"""

using EzXML, DataFrames, HTTP

export extract_concepts

"""
    extract_concepts(doc::EzXML.Document) -> DataFrame

Extracts concepts, their descriptions, variable mappings, and roles (dimension, attribute, measure, time dimension) from an SDMX structure document.

# Arguments
- `doc::EzXML.Document`: The parsed SDMX XML document.

# Returns
- `DataFrame`: A DataFrame with columns: `concept_id`, `description`, `variable`, `role`.
"""
function extract_concepts(doc::EzXML.Document)
    rootnode = root(doc)
    # Find all ConceptScheme nodes
    concept_nodes = findall("//structure:Concept", rootnode)
    # Map concept id to description
    concept_map = Dict{String, String}()
    for node in concept_nodes
        cid = node["id"]
        desc = missing
        name_nodes = findall(".//common:Name", node)
        if !isempty(name_nodes)
            desc = nodecontent(name_nodes[1])
        end
        concept_map[cid] = desc
    end
    # Find DSD (DataStructureDefinition) and its components
    # Dimensions
    dim_nodes = findall("//structure:Dimension", rootnode)
    # Attributes
    attr_nodes = findall("//structure:Attribute", rootnode)
    # Measures
    meas_nodes = findall("//structure:PrimaryMeasure", rootnode)
    # Time dimension
    time_nodes = findall("//structure:TimeDimension", rootnode)
    # Collect all
    rows = []
    for node in dim_nodes
        concept_ref = findfirst(".//structure:ConceptIdentity/Ref", node)
        if concept_ref !== nothing
            cid = concept_ref["id"]
            push!(rows, (concept_id=cid, description=get(concept_map, cid, missing), variable=node["id"], role="dimension"))
        end
    end
    for node in attr_nodes
        concept_ref = findfirst(".//structure:ConceptIdentity/Ref", node)
        if concept_ref !== nothing
            cid = concept_ref["id"]
            push!(rows, (concept_id=cid, description=get(concept_map, cid, missing), variable=node["id"], role="attribute"))
        end
    end
    for node in meas_nodes
        concept_ref = findfirst(".//structure:ConceptIdentity/Ref", node)
        if concept_ref !== nothing
            cid = concept_ref["id"]
            push!(rows, (concept_id=cid, description=get(concept_map, cid, missing), variable=node["id"], role="measure"))
        end
    end
    for node in time_nodes
        concept_ref = findfirst(".//structure:ConceptIdentity/Ref", node)
        if concept_ref !== nothing
            cid = concept_ref["id"]
            push!(rows, (concept_id=cid, description=get(concept_map, cid, missing), variable=node["id"], role="time_dimension"))
        end
    end
    return DataFrame(rows)
end

"""
    extract_concepts(xml_string::String) -> DataFrame

Convenience wrapper to download, parse, and extract all concept data from a URL or parse XML string.
This function automatically detects whether the string is a URL or XML content.
"""
function extract_concepts(input::String)
    try
        # Use the robust URL handling from SDMXHelpers
        xml_string = fetch_sdmx_xml(input)
        doc = parsexml(xml_string)
        return extract_concepts(doc)
    catch e
        println("Error during HTTP request or parsing: ", e)
        return DataFrame(concept_id=String[], description=String[], variable=String[], role=String[])
    end
end 
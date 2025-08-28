"""
Integration Examples and Utilities for Generated Function SDMX Parsing

This module provides examples, benchmarks, and migration utilities for the new
@generated function-based SDMX parsing system. It demonstrates how to use the
type-specialized parsing functions and provides performance comparisons.
"""

using EzXML
using ..SDMX: SDMXElement, DimensionElement, AttributeElement, MeasureElement, 
              extract_sdmx_element, get_xpath_patterns


"""
    demonstrate_generated_parsing() -> Nothing

Demonstrate the usage of generated function SDMX parsing with examples.

This function provides a comprehensive demonstration of how to use the new
@generated function system for parsing different types of SDMX elements,
showing the performance benefits and ease of use.

# Examples
```julia
# Run the full demonstration
demonstrate_generated_parsing()

# This will show examples of:
# - Type-specialized parsing for different element types
# - Performance comparisons with traditional methods
# - Integration with existing SDMX workflows
```

# See also
[`extract_sdmx_element`](@ref), [`benchmark_all_element_types`](@ref)
"""
function demonstrate_generated_parsing()
    println("🚀 Generated Function SDMX Parsing Demonstration")
    println("=" ^ 60)
    
    # Example XML content for demonstration
    sample_xml = """
    <structure:DataStructure xmlns:structure="http://www.sdmx.org/resources/sdmxml/schemas/v2_1/structure"
                            xmlns:common="http://www.sdmx.org/resources/sdmxml/schemas/v2_1/common">
        <structure:Dimension id="COUNTRY" position="1">
            <structure:ConceptIdentity>
                <Ref id="COUNTRY" maintainableParentID="CONCEPTS"/>
            </structure:ConceptIdentity>
            <structure:LocalRepresentation>
                <structure:Enumeration>
                    <Ref id="COUNTRY_CODES" agencyID="SDMX"/>
                </structure:Enumeration>
            </structure:LocalRepresentation>
        </structure:Dimension>
        
        <structure:Attribute id="UNIT_MEASURE" assignmentStatus="Mandatory">
            <structure:ConceptIdentity>
                <Ref id="UNIT_MEASURE"/>
            </structure:ConceptIdentity>
            <structure:AttributeRelationship>
                <structure:PrimaryMeasure/>
            </structure:AttributeRelationship>
        </structure:Attribute>
        
        <structure:PrimaryMeasure id="OBS_VALUE">
            <structure:ConceptIdentity>
                <Ref id="OBS_VALUE"/>
            </structure:ConceptIdentity>
            <structure:LocalRepresentation>
                <structure:TextFormat textType="Double" decimals="2"/>
            </structure:LocalRepresentation>
        </structure:PrimaryMeasure>
    </structure:DataStructure>
    """
    
    doc = parsexml(sample_xml)
    root_node = root(doc)
    
    # Find sample nodes
    dim_node = findfirst(".//structure:Dimension", root_node)
    attr_node = findfirst(".//structure:Attribute", root_node)
    measure_node = findfirst(".//structure:PrimaryMeasure", root_node)
    
    if dim_node !== nothing && attr_node !== nothing && measure_node !== nothing
        println("\\n📊 Parsing Different Element Types:")
        println("-" ^ 40)
        
        # Demonstrate dimension parsing
        println("\\n🎯 Dimension Element:")
        dim_data = extract_sdmx_element(DimensionElement, dim_node)
        println("  ID: " * string(dim_data.dimension_id))
        println("  Position: " * string(dim_data.position))
        println("  Concept: " * string(dim_data.concept_id))
        println("  Codelist: " * string(dim_data.codelist_id))
        
        # Demonstrate attribute parsing
        println("\\n🏷️  Attribute Element:")
        attr_data = extract_sdmx_element(AttributeElement, attr_node)
        println("  ID: " * string(attr_data.attribute_id))
        println("  Assignment: " * string(attr_data.assignment_status))
        println("  Attachment: " * string(attr_data.attachment_level))
        
        # Demonstrate measure parsing
        println("\\n📈 Measure Element:")
        measure_data = extract_sdmx_element(MeasureElement, measure_node)
        println("  ID: " * string(measure_data.measure_id))
        println("  Data Type: " * string(measure_data.data_type))
        println("  Decimals: " * string(measure_data.decimals))
        
        println("\\n⚡ Performance Benefits:")
        println("-" ^ 25)
        println("✅ Compile-time XPath optimization")
        println("✅ Type-specialized extraction paths")
        println("✅ Reduced memory allocations")
        println("✅ Better compiler optimization")
        
        println("\\n🎉 Generated function parsing demonstrated successfully!")
    else
        println("❌ Could not find sample nodes in XML")
    end
end

# Benchmark functions removed per user request - SDMX processing doesn't need to be ultra-fast

"""
    migration_guide() -> Nothing

Provide a comprehensive guide for migrating to generated function parsing.

This function explains how to update existing code to use the new @generated
function system while maintaining compatibility and gaining performance benefits.

# Examples
```julia
# Display migration instructions
migration_guide()
```

# See also
[`extract_sdmx_element`](@ref), [`demonstrate_generated_parsing`](@ref)
"""
function migration_guide()
    println("🔄 Migration Guide: Upgrading to Generated Function Parsing")
    println("=" ^ 60)
    
    println("\\n📝 Step 1: Update Function Calls")
    println("-" ^ 35)
    println("Old approach:")
    println("```julia")
    println("# Traditional parsing")
    println("dim_data = extract_dimension_info(dim_node)")
    println("attr_data = extract_attribute_info(attr_node)")
    println("```")
    
    println("\\nNew approach:")
    println("```julia")
    println("# Generated function parsing")
    println("dim_data = extract_sdmx_element(DimensionElement, dim_node)")
    println("attr_data = extract_sdmx_element(AttributeElement, attr_node)")
    println("```")
    
    println("\\n🎯 Step 2: Import Required Types")
    println("-" ^ 35)
    println("```julia")
    println("using SDMX: DimensionElement, AttributeElement, MeasureElement,")
    println("           extract_sdmx_element")
    println("```")
    
    println("\\n⚡ Step 3: Update Batch Processing")
    println("-" ^ 35)
    println("```julia")
    println("# Process multiple elements efficiently")
    println("dimensions = [extract_sdmx_element(DimensionElement, node) ")
    println("             for node in dimension_nodes]")
    println("             ")
    println("attributes = [extract_sdmx_element(AttributeElement, node)")
    println("             for node in attribute_nodes]")
    println("```")
    
    println("\\n🔧 Step 4: Performance Monitoring")
    println("-" ^ 35)
    println("```julia")
    println("# Benchmark your specific use case")
    println("results = benchmark_parsing_performance(DimensionElement, sample_node)")
    println("println(\\\"Speedup: \\$(results.speedup_factor)x\\\")")
    println("```")
    
    println("\\n✅ Benefits After Migration:")
    println("-" ^ 30)
    println("• Immediate performance improvements")
    println("• Better type safety at compile time")
    println("• Enhanced IDE support")
    println("• Future-proof API design")
    
    println("\\n🎉 Migration completed! Enjoy faster SDMX parsing!")
end

# =================== HELPER FUNCTIONS ===================

"""
    create_benchmark_xml() -> String

Create sample XML content for benchmarking generated function performance.
"""
function create_benchmark_xml()
    return \"\"\"
    <?xml version="1.0" encoding="UTF-8"?>
    <structure:DataStructure xmlns:structure="http://www.sdmx.org/resources/sdmxml/schemas/v2_1/structure"
                            xmlns:common="http://www.sdmx.org/resources/sdmxml/schemas/v2_1/common">
        <structure:Dimension id="COUNTRY" position="1">
            <structure:ConceptIdentity>
                <Ref id="COUNTRY" maintainableParentID="CONCEPTS"/>
            </structure:ConceptIdentity>
            <structure:LocalRepresentation>
                <structure:Enumeration>
                    <Ref id="COUNTRY_CODES" agencyID="SDMX"/>
                </structure:Enumeration>
            </structure:LocalRepresentation>
        </structure:Dimension>
        
        <structure:Attribute id="UNIT_MEASURE" assignmentStatus="Mandatory">
            <structure:ConceptIdentity>
                <Ref id="UNIT_MEASURE"/>
            </structure:ConceptIdentity>
            <structure:AttributeRelationship>
                <structure:PrimaryMeasure/>
            </structure:AttributeRelationship>
        </structure:Attribute>
        
        <structure:PrimaryMeasure id="OBS_VALUE">
            <structure:ConceptIdentity>
                <Ref id="OBS_VALUE"/>
            </structure:ConceptIdentity>
            <structure:LocalRepresentation>
                <structure:TextFormat textType="Double" decimals="2"/>
            </structure:LocalRepresentation>
        </structure:PrimaryMeasure>
    </structure:DataStructure>
    """
end
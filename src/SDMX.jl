"""
SDMX.jl - A Julia package for reading and parsing SDMX structural metadata into handy structures (e.g., DataFrames).

This package provides utilities to extract codelists and codes from SDMX-ML XML documents, making it easy to work with SDMX metadata in Julia.
"""
module SDMX

using EzXML, DataFrames, HTTP, CSV, XLSX, Statistics, Dates, JSON3, StatsBase

include("SDMXCodelists.jl")
include("SDMXConcepts.jl")
include("SDMXDataflows.jl")
include("SDMXAvailability.jl")
include("SDMXSourceData.jl")
include("SDMXValidation.jl")
include("SDMXPipelineOps.jl")
include("SDMXDataQueries.jl")
include("SDMXHelpers.jl")

# Note: Data source abstractions moved to SDMXLLM.jl package

# Pipeline operators and workflow functions
export validate_with, profile_with, map_with, generate_with, chain, pipeline
export tap, branch, parallel_map, SDMXPipeline

# Custom pipeline operators (working Unicode)  
export ⊆, ⇒

# Codelist extraction functions
export get_parent_id, process_code_node, extract_codes_from_codelist_node
export extract_all_codelists, filter_codelists_by_availability, get_available_codelist_summary
export construct_availability_url, map_codelist_to_dimension

# Schema and concept extraction
export extract_concepts, DataflowSchema, extract_dataflow_schema
export get_required_columns, get_optional_columns, get_codelist_columns, get_dimension_order

# Availability constraint functions
export AvailabilityConstraint, DimensionAvailability, TimeAvailability
export extract_availability, get_available_values, get_time_coverage
export compare_schema_availability, get_data_coverage_summary, find_data_gaps, print_availability_summary

# Source data profiling
export SourceDataProfile, ColumnProfile, read_source_data, profile_source_data
export suggest_column_mappings, print_source_profile

# Validation system
export ValidationResult, ValidationRule, ValidationSeverity, SDMXValidator
export create_validator, validate_sdmx_csv, validate_structure, validate_content, validate_quality
export generate_validation_report, fix_validation_issues, add_custom_validation_rule
export get_validation_summary, export_validation_results, preview_validation_output

# Data query functions
export construct_data_url, fetch_sdmx_data, query_sdmx_data, construct_sdmx_key, summarize_data

# Helper functions
export is_url, normalize_sdmx_url, fetch_sdmx_xml

end # module SDMX 
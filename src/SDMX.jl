"""
SDMX.jl - A Julia package for reading and parsing SDMX structural metadata into handy structures (e.g., DataFrames).

This package provides utilities to extract codelists and codes from SDMX-ML XML documents, making it easy to work with SDMX metadata in Julia.
"""
module SDMX

using EzXML, DataFrames, HTTP, CSV, Statistics, Dates, JSON3, StatsBase

include("SDMXElementTypes.jl")
include("SDMXGeneratedParsing.jl")
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

# === CORE DATA STRUCTURES ===
# Primary types for SDMX schema, data profiling, validation, and availability analysis
export DataflowSchema, SourceDataProfile, ColumnProfile
export AvailabilityConstraint, DimensionAvailability, TimeAvailability  
export ValidationResult, ValidationRule, ValidationSeverity, SDMXValidator

# === GENERATED FUNCTION TYPES & PARSING ===
# Type-specialized parsing system using @generated functions for compile-time optimization
export SDMXElement, DimensionElement, AttributeElement, MeasureElement, ConceptElement, CodelistElement, AvailabilityElement, TimeElement
export extract_sdmx_element, get_xpath_patterns
# Generated function integration utilities removed for simplicity

# === SDMX SCHEMA & METADATA EXTRACTION ===
# Functions for extracting and analyzing SDMX schema structures and concepts
export extract_concepts, extract_dataflow_schema
export get_required_columns, get_optional_columns, get_codelist_columns, get_dimension_order

# === CODELIST PROCESSING ===
# Functions for extracting, processing, and mapping SDMX codelists
export get_parent_id, process_code_node, extract_codes_from_codelist_node
export extract_all_codelists, filter_codelists_by_availability, get_available_codelist_summary
export construct_availability_url, map_codelist_to_dimension

# === DATA AVAILABILITY ANALYSIS ===
# Functions for analyzing data availability constraints and coverage
export extract_availability, extract_availability_from_dataflow, get_available_values, get_time_coverage
export compare_schema_availability, get_data_coverage_summary, find_data_gaps, print_availability_summary

# === SOURCE DATA PROCESSING & PROFILING ===
# Functions for reading, profiling, and analyzing source data files
export read_source_data, profile_source_data, suggest_column_mappings, print_source_profile

# === DATA VALIDATION SYSTEM ===
# Comprehensive validation framework for SDMX data quality and compliance
export create_validator, validate_sdmx_csv
export generate_validation_report, preview_validation_output

# === DATA QUERY & RETRIEVAL ===
# Functions for constructing queries and retrieving SDMX data from APIs
export construct_data_url, fetch_sdmx_data, query_sdmx_data, construct_sdmx_key, summarize_data

# === PIPELINE OPERATIONS & WORKFLOW ===
# Functional programming interface for chaining SDMX operations
export validate_with, profile_with, chain, pipeline
export tap, branch, parallel_map, SDMXPipeline

# === PIPELINE OPERATORS (Unicode) ===
# Custom operators for expressive SDMX data pipeline construction
export ⊆, ⇒

# === UTILITY FUNCTIONS ===
# Helper functions for URL handling and XML processing
export is_url, normalize_sdmx_url, fetch_sdmx_xml

end # module SDMX 
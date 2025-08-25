# SDMX.jl

[![Build Status](https://github.com/yourusername/julia_sdmx/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/yourusername/julia_sdmx/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/yourusername/julia_sdmx/branch/main/graph/badge.svg)](https://codecov.io/gh/yourusername/julia_sdmx)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

Core Julia package for SDMX (Statistical Data and Metadata eXchange) processing. Extract and analyze structural metadata from SDMX-ML documents, including codelists, concepts, dataflow schemas, and data availability constraints.

## Requirements

- Julia 1.11 or higher
- See [Project.toml](Project.toml) for package dependencies

## Features

- 📊 **SDMX Schema Extraction**: Parse dataflow definitions, dimensions, and measures
- 📝 **Codelist Management**: Extract and filter codelists with availability constraints
- 🔍 **Data Profiling**: Analyze source data structure and quality
- 🎯 **Intelligent Mapping**: Suggest column mappings between source data and SDMX schemas
- ✅ **Validation**: Comprehensive SDMX compliance checking
- 🔗 **Pipeline Operations**: Composable data transformation workflows

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/SDMX.jl")
# or for development
Pkg.develop(path="path/to/SDMX.jl")
```

## Quick Start

```julia
using SDMX
using DataFrames

# Extract SDMX schema from Pacific Data Hub
url = "https://stats-sdmx-disseminate.pacificdata.org/rest/dataflow/SPC/DF_BP50/latest?references=all"
schema = extract_dataflow_schema(url)

# View schema information
println("Dataflow: " * schema.dataflow_info.name)
println("Required columns: " * join(get_required_columns(schema), ", "))

# Extract codelists (filtered to only used values)
codelists = extract_all_codelists(url, true)
println("Found " * string(nrow(codelists)) * " codes across " * 
        string(length(unique(codelists.codelist_id))) * " codelists")

# Profile your source data
source_data = CSV.read("my_data.csv", DataFrame)
profile = profile_source_data(source_data, "my_data.csv")
print_source_profile(profile)

# Get mapping suggestions
mappings = suggest_column_mappings(profile, schema)
for (target, sources) in mappings
    println(target * " <- " * join(sources, ", "))
end
```

## Core Modules

### SDMXDataflows
Extract and analyze dataflow schemas:
```julia
schema = extract_dataflow_schema(url)
required_cols = get_required_columns(schema)
optional_cols = get_optional_columns(schema)
codelist_cols = get_codelist_columns(schema)
```

### SDMXCodelists
Manage dimension codelists:
```julia
# Get all codelists
all_codes = extract_all_codelists(url)

# Get only codes that appear in actual data
used_codes = extract_all_codelists(url, true)

# Extract specific codelist
geo_codes = extract_codelist_from_url(url, "CL_GEO_PICT")
```

### SDMXAvailability
Analyze actual data availability:
```julia
# Get data availability constraints
avail_url = construct_availability_url(dataflow_url)
availability = extract_availability(avail_url)

# Check what data exists
countries = get_available_values(availability, "GEO_PICT")
time_range = get_time_coverage(availability)
print_availability_summary(availability)

# Find data gaps
gaps = find_data_gaps(availability, expected_values)
```

### SDMXSourceData
Profile and analyze source data:
```julia
# Smart data loading (CSV/Excel)
data = read_source_data("file.xlsx")

# Comprehensive profiling
profile = profile_source_data(data, "file.xlsx")
print_source_profile(profile)

# Column analysis
temporal_cols = get_temporal_columns(profile)
categorical_cols = get_categorical_columns(profile)
numeric_cols = get_numeric_columns(profile)
```

### SDMXMappingInference
Advanced mapping with fuzzy matching:
```julia
# Create inference engine
engine = create_inference_engine(
    fuzzy_threshold=0.7,
    min_confidence=0.3
)

# Infer mappings
result = infer_advanced_mappings(engine, profile, schema, source_data)
println("Mapping quality: " * string(result.quality_score))

# Analyze specific mappings
score = fuzzy_match_score("country", "GEO_PICT")
patterns = analyze_value_patterns(values, codelist)
```

### SDMXValidation
Validate SDMX compliance:
```julia
# Validate data structure
validation = validate_dataframe(df, schema)
if !validation.is_valid
    println("Validation errors: " * join(validation.errors, "\n"))
end

# Check specific validations
is_valid_time_format("2024-01")  # true
is_valid_observation_value("123.45")  # true
```

### SDMXPipelineOps
Composable pipeline operations:
```julia
using SDMX: @sdmx_pipeline

# Define transformation pipeline
@sdmx_pipeline function transform_data(data)
    data |>
    profile_with() |>
    validate_with(schema) |>
    map_with(mappings) |>
    output_to("transformed.csv")
end

# Check if data conforms to schema
if data ⊆ schema
    println("Data structure matches SDMX schema")
end
```

## API Reference

### Schema Functions
- `extract_dataflow_schema(url)` - Extract complete dataflow schema
- `get_required_columns(schema)` - Get mandatory SDMX columns
- `get_optional_columns(schema)` - Get optional SDMX columns
- `get_time_dimension(schema)` - Get time dimension information

### Codelist Functions
- `extract_all_codelists(url, filter_by_availability)` - Extract all codelists
- `extract_codelist_from_url(url, codelist_id)` - Extract specific codelist
- `get_codelist_for_dimension(schema, dimension)` - Get codelist for dimension

### Data Analysis Functions
- `profile_source_data(data, filepath)` - Profile data structure
- `suggest_column_mappings(profile, schema)` - Basic mapping suggestions
- `infer_column_mappings(data, schema)` - Direct data-to-schema mapping

### Validation Functions
- `validate_dataframe(df, schema)` - Validate against SDMX schema
- `is_valid_time_format(str)` - Check time format validity
- `is_valid_observation_value(str)` - Check observation value

## Working with Pacific Data Hub

```julia
# Example: Balance of Payments data
base_url = "https://stats-sdmx-disseminate.pacificdata.org/rest/"
dataflow = "dataflow/SPC/DF_BP50/latest?references=all"

# Full workflow
schema = extract_dataflow_schema(base_url * dataflow)
codelists = extract_all_codelists(base_url * dataflow, true)
availability = extract_availability(construct_availability_url(base_url * dataflow))

# Analyze coverage
summary = get_data_coverage_summary(availability)
print_availability_summary(availability)

# Profile your data
my_data = CSV.read("pacific_trade_data.csv", DataFrame)
profile = profile_source_data(my_data, "pacific_trade_data.csv")

# Map and validate
mappings = suggest_column_mappings(profile, schema)
validation = validate_dataframe(my_data, schema)
```

## Testing

Run the test suite:
```julia
using Pkg
Pkg.test("SDMX")
```

All 108 tests should pass, covering:
- Dataflow schema extraction
- Codelist management
- Data availability analysis
- Source data profiling
- Mapping inference
- Validation logic
- Pipeline operations

## Contributing

Contributions welcome! Please ensure:
1. All tests pass
2. New features include tests
3. Code follows Julia style conventions
4. Documentation is updated

## License

MIT License - see [LICENSE](LICENSE) file for details.

## See Also

- [SDMXLLM.jl](../SDMXLLM.jl) - LLM-powered extension for advanced transformations
- [SDMX.org](https://sdmx.org) - Official SDMX documentation
- [Pacific Data Hub](https://pacificdata.org) - Pacific region statistics
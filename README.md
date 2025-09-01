# SDMX.jl

[![Build Status](https://github.com/Baffelan/SDMX.jl/workflows/CI/badge.svg)](https://github.com/Baffelan/SDMX.jl/actions/workflows/CI.yml)
[![Coverage](https://codecov.io/gh/Baffelan/SDMX.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Baffelan/SDMX.jl)
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
- 📡 **Data Queries**: Construct and execute SDMX data queries
- ⚡ **High-Performance Parsing**: Generated function system for optimized element extraction

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/Baffelan/SDMX.jl")
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
dimension_order = get_dimension_order(schema)
```

### SDMXCodelists
Manage dimension codelists:
```julia
# Get all codelists
all_codes = extract_all_codelists(url)

# Get only codes that appear in actual data
used_codes = extract_all_codelists(url, true)

# Filter by availability
filtered_codes = filter_codelists_by_availability(codelists_df, dataflow_url)

# Map codelist to dimension
dimension_id = map_codelist_to_dimension(codelist_id)
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

# Analyze coverage
summary = get_data_coverage_summary(availability)
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

# Suggest mappings
mappings = suggest_column_mappings(profile, schema)
```

### SDMXValidation
Validate SDMX compliance:
```julia
# Create validator
validator = create_validator(schema)

# Validate CSV file
result = validate_sdmx_csv(validator, "data.csv")

# Generate validation report
report = generate_validation_report(result)
preview_validation_output(result)

# Check specific format
is_valid = is_valid_time_format("2024-01")  # true
```

### SDMXDataQueries
Query and retrieve SDMX data:
```julia
# Construct data URL
data_url = construct_data_url(base_url, agency_id, dataflow_id, version)

# Fetch SDMX data
data = fetch_sdmx_data(url)

# Query with filters
result = query_sdmx_data(base_url, agency_id, dataflow_id, 
                         filters=Dict("GEO_PICT" => "FJ"))

# Summarize data
summary = summarize_data(data)

# Construct SDMX key
key = construct_sdmx_key(schema, filters)
```

### SDMXPipelineOps
Composable pipeline operations:
```julia
# Define transformation pipeline
pipeline = chain(
    profile_with("source.csv"),
    validate_with(schema),
    tap(df -> println("Processing " * string(nrow(df)) * " rows"))
)

# Apply pipeline
result = data |> pipeline

# Check conformance
if data ⊆ schema
    println("Data structure matches SDMX schema")
end

# Validate with operator
validated = data ⇒ validator

# Branch on condition
branched = branch(
    df -> nrow(df) > 1000,
    df -> parallel_map(process_chunk)(df),
    df -> process_small(df)
)
```

### SDMXHelpers
Utility functions:
```julia
# Check if string is URL
is_url("https://example.com")  # true

# Normalize SDMX URL
normalized = normalize_sdmx_url(url)

# Fetch SDMX XML
doc = fetch_sdmx_xml(url_or_file)
```

## API Reference

### Core Data Structures
- `DataflowSchema` - Complete SDMX dataflow schema
- `SourceDataProfile` - Source data profiling results
- `ColumnProfile` - Individual column analysis
- `AvailabilityConstraint` - Data availability information
- `ValidationResult` - Validation outcome with issues
- `SDMXValidator` - Configurable validation engine

### Schema Functions
- `extract_dataflow_schema(url)` - Extract complete dataflow schema
- `extract_concepts(url)` - Extract concept definitions
- `get_required_columns(schema)` - Get mandatory SDMX columns
- `get_optional_columns(schema)` - Get optional SDMX columns
- `get_codelist_columns(schema)` - Get columns with codelists
- `get_dimension_order(schema)` - Get dimension ordering

### Codelist Functions
- `extract_all_codelists(url, filter_by_availability)` - Extract all codelists
- `filter_codelists_by_availability(codelists, url)` - Filter by availability
- `get_available_codelist_summary(url)` - Get codelist summary
- `map_codelist_to_dimension(codelist_id)` - Map to dimension ID

### Data Analysis Functions
- `profile_source_data(data, filepath)` - Profile data structure
- `suggest_column_mappings(profile, schema)` - Basic mapping suggestions
- `print_source_profile(profile)` - Display profile summary

### Validation Functions
- `create_validator(schema; kwargs...)` - Create validator instance
- `validate_sdmx_csv(validator, filepath)` - Validate CSV file
- `generate_validation_report(result)` - Generate report
- `preview_validation_output(result)` - Preview issues
- `is_valid_time_format(str)` - Check time format validity

### Data Query Functions
- `construct_data_url(base, agency, dataflow, version)` - Build URL
- `fetch_sdmx_data(url)` - Fetch data from API
- `query_sdmx_data(base, agency, dataflow; kwargs...)` - Query with filters
- `construct_sdmx_key(schema, filters)` - Build query key
- `summarize_data(data)` - Get data summary

### Pipeline Functions
- `chain(operations...)` - Chain operations
- `pipeline(operations...)` - Create pipeline
- `validate_with(schema)` - Validation operation
- `profile_with(filename)` - Profiling operation
- `tap(function)` - Side-effect operation
- `branch(condition, true_path, false_path)` - Conditional branch
- `parallel_map(function)` - Parallel processing

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
validator = create_validator(schema)
validation = validate_sdmx_csv(validator, "pacific_trade_data.csv")
```

## Testing

Run the test suite:
```julia
using Pkg
Pkg.test("SDMX")
```

Tests cover:
- Dataflow schema extraction
- Codelist management
- Data availability analysis
- Source data profiling
- Validation logic
- Pipeline operations
- Data queries

## Contributing

Contributions welcome! Please ensure:
1. All tests pass
2. New features include tests
3. Code follows Julia style conventions
4. Documentation is updated

## Documentation

Detailed documentation for specific features:

- **[Generated Function Parsing](docs/GENERATED_PARSING.md)**: High-performance element extraction system with compile-time optimization
- **API Reference**: See exported functions in each module
- **Examples**: Check the `test/` directory for comprehensive usage examples

## License

MIT License - see [LICENSE](LICENSE) file for details.

## See Also

- [SDMXLLM.jl](www.github.com/Baffelan/SDMXLLM.jl) - LLM-powered extension for advanced transformations
- [SDMX.org](https://sdmx.org) - Official SDMX documentation
- [PDH .Stat](https://stats.pacificdata.org) - Pacific region SDMX .Stat Data Explorer

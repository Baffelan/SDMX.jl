# SDMX.jl - Statistical Data and Metadata eXchange for Julia

[![Julia](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A Julia package for reading and parsing SDMX (Statistical Data and Metadata eXchange) structural metadata into handy structures like DataFrames. Extract codelists, concepts, and data availability constraints from SDMX-ML XML documents.

## 📦 Installation

```julia
using Pkg
Pkg.develop(path="path/to/SDMX.jl")
```

## 🎯 Quick Start

### Basic SDMX Schema Analysis

```julia
using SDMX

# Extract dataflow schema from SDMX API
url = "https://stats-sdmx-disseminate.pacificdata.org/rest/dataflow/SPC/DF_BP50/latest?references=all"
schema = extract_dataflow_schema(url)

# Explore the schema
println("Dataflow: $(schema.dataflow_info.name)")
println("Required columns: $(get_required_columns(schema))")
println("Optional columns: $(get_optional_columns(schema))")

# Extract codelists
codelists_df = extract_all_codelists(url)
println("Available codelists: $(unique(codelists_df.codelist_id))")

# Filter codelists to only codes that appear in published data
filtered_codelists = extract_all_codelists(url, true)  # true = filter by availability
println("Filtered to $(nrow(filtered_codelists)) codes that are actually used")
```

### Data Availability Analysis

```julia
# Extract actual data availability constraints
availability_url = construct_availability_url(url)
availability = extract_availability(availability_url)

# Show availability summary
print_availability_summary(availability)

# Get available values for specific dimensions
countries_with_data = get_available_values(availability, "GEO_PICT")
indicators_with_data = get_available_values(availability, "INDICATOR")
println("Countries with data: $(join(countries_with_data, ", "))")
println("Indicators with data: $(join(indicators_with_data, ", "))")

# Check time coverage
time_coverage = get_time_coverage(availability)
println("Data period: $(time_coverage.start_date) to $(time_coverage.end_date)")
```

### Source Data Analysis

```julia
# Load and profile your source data
source_data = read_source_data("my_data.csv")
profile = profile_source_data(source_data, "my_data.csv")

# View data quality assessment
print_source_profile(profile)

# Get intelligent mapping suggestions
mappings = suggest_column_mappings(profile, schema)
println("Suggested mappings:")
for (target_col, source_cols) in mappings
    println("  $target_col ← $(join(source_cols, ", "))")
end
```

## 🔧 Core Functions Reference

### SDMX Schema Functions

| Function | Description | Example |
|----------|-------------|---------|
| `extract_dataflow_schema(url)` | Extract complete dataflow schema | `schema = extract_dataflow_schema(url)` |
| `extract_all_codelists(url)` | Get all codelists as DataFrame | `codelists = extract_all_codelists(url)` |
| `extract_all_codelists(url, true)` | Get filtered codelists (only used codes) | `filtered = extract_all_codelists(url, true)` |
| `extract_concepts(url)` | Extract concept definitions | `concepts = extract_concepts(url)` |
| `get_required_columns(schema)` | List required SDMX columns | `required = get_required_columns(schema)` |
| `get_optional_columns(schema)` | List optional SDMX columns | `optional = get_optional_columns(schema)` |
| `get_codelist_columns(schema)` | Get columns with codelists | `codelists = get_codelist_columns(schema)` |

### SDMX Availability Functions

| Function | Description | Example |
|----------|-------------|---------|
| `extract_availability(url)` | Extract data availability constraints | `avail = extract_availability(url)` |
| `construct_availability_url(dataflow_url)` | Build availability URL from dataflow URL | `url = construct_availability_url(dataflow_url)` |
| `get_available_values(avail, dim)` | Get available values for dimension | `countries = get_available_values(avail, "GEO_PICT")` |
| `get_time_coverage(avail)` | Get time period coverage | `time_info = get_time_coverage(avail)` |
| `compare_schema_availability(schema, avail)` | Compare schema vs actual data | `comparison = compare_schema_availability(schema, avail)` |
| `find_data_gaps(avail, expected)` | Find missing dimension values | `gaps = find_data_gaps(avail, expected_values)` |
| `get_data_coverage_summary(avail)` | Summary DataFrame of coverage | `summary = get_data_coverage_summary(avail)` |
| `print_availability_summary(avail)` | Print formatted availability summary | `print_availability_summary(avail)` |

### Data Analysis Functions

| Function | Description | Example |
|----------|-------------|---------|
| `read_source_data(filepath)` | Smart data loading (CSV/Excel) | `data = read_source_data("file.csv")` |
| `profile_source_data(data, filepath)` | Comprehensive data profiling | `profile = profile_source_data(data, "file.csv")` |
| `suggest_column_mappings(profile, schema)` | Basic mapping suggestions | `mappings = suggest_column_mappings(profile, schema)` |
| `print_source_profile(profile)` | Print formatted profile summary | `print_source_profile(profile)` |

### Advanced Mapping Functions

| Function | Description | Example |
|----------|-------------|---------|
| `create_inference_engine(options...)` | Create intelligent mapper | `engine = create_inference_engine()` |
| `infer_advanced_mappings(engine, profile, schema)` | AI-powered mapping | `mappings = infer_advanced_mappings(engine, profile, schema)` |
| `fuzzy_match_score(str1, str2)` | Calculate string similarity | `score = fuzzy_match_score("country", "GEO_PICT")` |
| `analyze_value_patterns(values, codelist)` | Pattern matching analysis | `patterns = analyze_value_patterns(values, codelist)` |
| `validate_mapping_quality(mappings)` | Assess mapping quality | `quality = validate_mapping_quality(mappings)` |

### LLM Integration Functions

| Function | Description | Example |
|----------|-------------|---------|
| `setup_llm_config(provider; options...)` | Configure LLM provider | `config = setup_llm_config(:ollama; model="llama3")` |
| `analyze_excel_structure(filepath)` | Analyze Excel workbook structure | `analysis = analyze_excel_structure("file.xlsx")` |
| `generate_transformation_script(args...)` | Generate transformation code | `script = generate_transformation_script(...)` |
| `query_llm(config, prompt)` | Direct LLM query | `response = query_llm(config, "Analyze this data...")` |

### Pipeline Operations

| Function | Description | Example |
|----------|-------------|---------|
| `validate_with(validator)` | Create validation pipeline step | `data \|> validate_with(validator)` |
| `profile_with(options)` | Create profiling pipeline step | `data \|> profile_with(detailed=true)` |
| `map_with(mappings)` | Create mapping pipeline step | `data \|> map_with(mappings)` |
| `generate_with(generator)` | Create generation pipeline step | `data \|> generate_with(script_gen)` |
| `chain(steps...)` | Chain multiple pipeline steps | `pipeline = chain(step1, step2, step3)` |

## 🎛️ Configuration Examples

### LLM Providers

```julia
# Local Ollama
config = setup_llm_config(:ollama; 
    model="llama3", 
    base_url="http://localhost:11434")

# OpenAI
config = setup_llm_config(:openai; 
    model="gpt-4", 
    api_key="your-key")

# Anthropic Claude  
config = setup_llm_config(:anthropic; 
    model="claude-3-sonnet", 
    api_key="your-key")
```

### Advanced Mapping Engine

```julia
# Create inference engine with custom settings
engine = create_inference_engine(
    fuzzy_threshold=0.7,
    min_confidence=0.3,
    enable_semantic_matching=true,
    learn_from_feedback=true
)

# Perform advanced mapping
result = infer_advanced_mappings(engine, profile, schema)
println("Mapping quality score: $(result.quality_score)")
```

## 📊 Real-World Example

### Pacific Data Hub Integration

```julia
# SPC Pacific Data Hub - Balance of Payments
spc_url = "https://stats-sdmx-disseminate.pacificdata.org/rest/dataflow/SPC/DF_BP50/latest?references=all"

# Extract schema and analyze your data
schema = extract_dataflow_schema(spc_url)
codelists = extract_all_codelists(spc_url, true)  # Only codes with actual data

# Load and profile source data
source_data = read_source_data("my_pacific_data.csv")
profile = profile_source_data(source_data, "my_pacific_data.csv")

# Get mapping suggestions
mappings = suggest_column_mappings(profile, schema)

# Advanced mapping with AI assistance
engine = create_inference_engine()
advanced_mappings = infer_advanced_mappings(engine, profile, schema)

println("Found $(length(advanced_mappings.mappings)) potential mappings")
println("Mapping confidence: $(round(advanced_mappings.quality_score, digits=2))")
```

## 🏗️ Data Pipeline

```julia
# Create a data processing pipeline
pipeline = chain(
    profile_with(detailed=true),
    map_with(schema_mappings),
    validate_with(sdmx_validator),
    generate_with(script_generator)
)

# Process data through pipeline
result = my_data |> pipeline
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Transform your data to SDMX format with SDMX.jl!** 🚀
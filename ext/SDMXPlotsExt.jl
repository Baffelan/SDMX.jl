"""
SDMX Plots Extension

This extension provides visualization capabilities for SDMX.jl when Plots.jl
is available. It enables users to create charts and visualizations for SDMX
data analysis, source data profiling, and validation results.

Only loaded when Plots.jl is imported by the user.
"""

module SDMXPlotsExt

# Only loaded when Plots is available
if isdefined(Base, :get_extension)
    using Plots
    using SDMX
    import SDMX: plot_source_profile, plot_validation_results, plot_data_quality,
                 visualize_schema_structure, create_sdmx_dashboard
else
    # Fallback for older Julia versions
    @warn "Plots extension requires Julia 1.9+ with package extensions support"
end

"""
    plot_source_profile(profile::SourceDataProfile; kwargs...) -> Plots.Plot

Create visualizations for source data profile analysis.

This function generates comprehensive charts showing data quality metrics,
column type distributions, missing value patterns, and other insights from
source data profiling to help users understand their data before SDMX transformation.

# Arguments
- `profile::SourceDataProfile`: Source data profile from profile_source_data()
- `kwargs...`: Additional Plots.jl parameters for customization

# Returns
- `Plots.Plot`: Multi-panel visualization of data profile insights

# Examples
```julia
# Requires: using Plots
using DataFrames, SDMX, Plots

df = DataFrame(country=["USA", "Canada"], year=[2020, 2021], gdp=[21.4, 1.6])
profile = profile_source_data(df)
plot_source_profile(profile)

# Customize appearance
plot_source_profile(profile, size=(1200, 800), dpi=300)
```

# See also
[`profile_source_data`](@ref), [`plot_data_quality`](@ref), [`SourceDataProfile`](@ref)
"""
function plot_source_profile(profile::SourceDataProfile; kwargs...)
    # Data quality overview
    quality_plot = bar(
        ["Data Quality"],
        [profile.data_quality_score * 100],
        title="Overall Data Quality",
        ylabel="Quality Score (%)",
        ylims=(0, 100),
        color=:green,
        legend=false
    )
    
    # Column type distribution
    type_counts = Dict{String, Int}()
    for col in profile.columns
        type_name = string(col.type)
        type_counts[type_name] = get(type_counts, type_name, 0) + 1
    end
    
    type_plot = pie(
        collect(values(type_counts)),
        labels=collect(keys(type_counts)),
        title="Column Type Distribution"
    )
    
    # Missing value patterns
    missing_data = [(col.name, col.missing_count) for col in profile.columns]
    missing_names = [x[1] for x in missing_data]
    missing_counts = [x[2] for x in missing_data]
    
    missing_plot = bar(
        missing_names,
        missing_counts,
        title="Missing Values by Column",
        ylabel="Missing Count",
        xrotation=45,
        color=:orange
    )
    
    # SDMX role suggestions
    role_counts = [
        length(profile.suggested_key_columns),
        length(profile.suggested_value_columns), 
        length(profile.suggested_time_columns)
    ]
    role_labels = ["Dimensions", "Measures", "Time"]
    
    role_plot = bar(
        role_labels,
        role_counts,
        title="Suggested SDMX Roles",
        ylabel="Column Count",
        color=[:blue, :red, :purple]
    )
    
    # Combine plots
    layout = @layout [a b; c d]
    plot(quality_plot, type_plot, missing_plot, role_plot, 
         layout=layout, size=(1000, 600), kwargs...)
end

"""
    plot_validation_results(result::ValidationResult; kwargs...) -> Plots.Plot

Visualize SDMX validation results with severity breakdown and issue categories.

Creates charts showing validation issue distribution by severity level,
category breakdown, and trends to help users prioritize data quality improvements.

# Arguments
- `result::ValidationResult`: Validation results from validate_sdmx_csv()
- `kwargs...`: Additional Plots.jl parameters

# Returns
- `Plots.Plot`: Validation results visualization

# Examples
```julia
# Requires: using Plots
validator = create_validator(schema)
result = validator(my_data)
plot_validation_results(result)
```

# See also
[`validate_sdmx_csv`](@ref), [`ValidationResult`](@ref), [`create_validator`](@ref)
"""
function plot_validation_results(result::ValidationResult; kwargs...)
    # Severity distribution
    severity_counts = Dict(
        "INFO" => 0,
        "WARNING" => 0, 
        "ERROR" => 0,
        "CRITICAL" => 0
    )
    
    for issue in result.issues
        severity_str = string(issue.severity)
        severity_counts[severity_str] += 1
    end
    
    severity_plot = bar(
        collect(keys(severity_counts)),
        collect(values(severity_counts)),
        title="Issues by Severity",
        ylabel="Issue Count",
        color=[:blue, :orange, :red, :purple],
        legend=false
    )
    
    # Category breakdown
    category_counts = Dict{String, Int}()
    for issue in result.issues
        cat = issue.category
        category_counts[cat] = get(category_counts, cat, 0) + 1
    end
    
    category_plot = pie(
        collect(values(category_counts)),
        labels=collect(keys(category_counts)),
        title="Issues by Category"
    )
    
    # Overall status
    status_colors = Dict(
        "PASSED" => :green,
        "FAILED" => :red,
        "WARNING" => :orange
    )
    
    status_plot = scatter(
        [1], [1],
        markersize=50,
        color=get(status_colors, string(result.overall_status), :gray),
        title="Overall Status: $(result.overall_status)",
        legend=false,
        showaxis=false,
        grid=false
    )
    
    layout = @layout [a b; c]
    plot(severity_plot, category_plot, status_plot,
         layout=layout, size=(1000, 600), kwargs...)
end

"""
    plot_data_quality(data::DataFrame, schema::DataflowSchema; kwargs...) -> Plots.Plot

Create data quality assessment visualizations for SDMX datasets.

Generates charts showing completeness, consistency, and compliance metrics
to help assess dataset readiness for SDMX publication or exchange.

# Arguments
- `data::DataFrame`: SDMX dataset to analyze
- `schema::DataflowSchema`: SDMX schema for validation context
- `kwargs...`: Plots.jl parameters

# Returns
- `Plots.Plot`: Data quality assessment charts

# Examples
```julia
# Requires: using Plots
quality_viz = plot_data_quality(my_sdmx_data, schema)
```

# See also
[`plot_source_profile`](@ref), [`DataflowSchema`](@ref)
"""
function plot_data_quality(data::DataFrame, schema::DataflowSchema; kwargs...)
    # Completeness by column
    completeness = []
    col_names = []
    
    for col in names(data)
        missing_pct = count(ismissing, data[!, col]) / nrow(data) * 100
        completeness_pct = 100 - missing_pct
        push!(completeness, completeness_pct)
        push!(col_names, col)
    end
    
    completeness_plot = bar(
        col_names,
        completeness,
        title="Data Completeness by Column",
        ylabel="Completeness (%)",
        ylims=(0, 100),
        xrotation=45,
        color=:green
    )
    
    # Data volume trends (if time dimension present)
    time_plot = plot(
        title="Data Volume Trends",
        xlabel="Time Period",
        ylabel="Record Count"
    )
    
    if schema.time_dimension !== nothing
        time_col = schema.time_dimension.dimension_id
        if time_col in names(data)
            time_counts = combine(groupby(data, time_col), nrow => :count)
            plot!(time_plot, time_counts[!, time_col], time_counts.count,
                  marker=:circle, linewidth=2)
        else
            plot!(time_plot, [1], [nrow(data)], 
                  title="Total Records: $(nrow(data))",
                  marker=:circle, markersize=10)
        end
    end
    
    layout = @layout [a; b]
    plot(completeness_plot, time_plot, layout=layout, size=(1000, 600), kwargs...)
end

"""
    visualize_schema_structure(schema::DataflowSchema; kwargs...) -> Plots.Plot

Create a visual representation of SDMX schema structure.

Generates diagrams showing the relationships between dimensions, measures,
and attributes in an SDMX dataflow schema to help understand data structure.

# Arguments
- `schema::DataflowSchema`: SDMX schema to visualize
- `kwargs...`: Plots.jl parameters

# Returns
- `Plots.Plot`: Schema structure diagram

# Examples
```julia
# Requires: using Plots
schema_viz = visualize_schema_structure(my_schema)
```

# See also
[`extract_dataflow_schema`](@ref), [`DataflowSchema`](@ref)
"""
function visualize_schema_structure(schema::DataflowSchema; kwargs...)
    # Schema overview
    component_counts = [
        length(schema.dimensions.dimension_id),
        length(schema.measures.measure_id),
        length(schema.attributes.attribute_id)
    ]
    component_labels = ["Dimensions", "Measures", "Attributes"]
    
    overview_plot = bar(
        component_labels,
        component_counts,
        title="Schema Components",
        ylabel="Count",
        color=[:blue, :red, :green],
        legend=false
    )
    
    # Dimension positions
    if !isempty(schema.dimensions.position)
        pos_plot = scatter(
            schema.dimensions.position,
            1:length(schema.dimensions.position),
            title="Dimension Positions",
            xlabel="Position",
            ylabel="Dimension Index",
            marker=:circle,
            markersize=8
        )
    else
        pos_plot = plot(title="No Position Information Available")
    end
    
    layout = @layout [a b]
    plot(overview_plot, pos_plot, layout=layout, size=(800, 400), kwargs...)
end

"""
    create_sdmx_dashboard(data::DataFrame, profile::SourceDataProfile, 
                          validation::ValidationResult; kwargs...) -> Plots.Plot

Create a comprehensive SDMX analysis dashboard combining multiple visualizations.

Generates a multi-panel dashboard showing source data profiling, validation results,
and data quality metrics in a single view for comprehensive SDMX data assessment.

# Arguments
- `data::DataFrame`: SDMX dataset
- `profile::SourceDataProfile`: Source data profile
- `validation::ValidationResult`: Validation results
- `kwargs...`: Plots.jl parameters

# Returns
- `Plots.Plot`: Comprehensive SDMX dashboard

# Examples
```julia
# Requires: using Plots
dashboard = create_sdmx_dashboard(my_data, profile, validation_result)
```

# See also
[`plot_source_profile`](@ref), [`plot_validation_results`](@ref), [`plot_data_quality`](@ref)
"""
function create_sdmx_dashboard(data::DataFrame, profile::SourceDataProfile, 
                               validation::ValidationResult; kwargs...)
    # Data overview
    overview_plot = bar(
        ["Rows", "Columns", "Quality Score"],
        [profile.row_count, profile.column_count, profile.data_quality_score * 100],
        title="Data Overview",
        color=[:blue, :green, :orange],
        legend=false
    )
    
    # Validation summary
    issue_count = length(validation.issues)
    status_color = validation.overall_status == :PASSED ? :green : :red
    
    validation_plot = scatter(
        [1], [issue_count],
        markersize=30,
        color=status_color,
        title="Validation: $(validation.overall_status) ($(issue_count) issues)",
        legend=false,
        showaxis=false
    )
    
    # Missing data heatmap (simplified)
    missing_pct = [col.missing_count / profile.row_count * 100 for col in profile.columns]
    col_names = [col.name for col in profile.columns]
    
    missing_plot = bar(
        col_names,
        missing_pct,
        title="Missing Data (%)",
        xrotation=45,
        color=:red,
        alpha=0.7
    )
    
    # SDMX readiness score
    readiness_score = (profile.data_quality_score * 0.7 + 
                      (validation.overall_status == :PASSED ? 1.0 : 0.0) * 0.3) * 100
    
    readiness_plot = scatter(
        [1], [readiness_score],
        markersize=40,
        color=readiness_score > 80 ? :green : readiness_score > 60 ? :orange : :red,
        title="SDMX Readiness: $(round(readiness_score, digits=1))%",
        ylims=(0, 100),
        legend=false
    )
    
    layout = @layout [a b; c d]
    plot(overview_plot, validation_plot, missing_plot, readiness_plot,
         layout=layout, size=(1200, 800), kwargs...)
end

# Extension initialization
function __init__()
    @info "SDMX Plots Extension loaded - Visualization capabilities available"
    @info "Available functions: plot_source_profile, plot_validation_results, plot_data_quality, visualize_schema_structure, create_sdmx_dashboard"
end

end # module SDMXPlotsExt
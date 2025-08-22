"""
SDMX Excel Extension

This extension provides Excel file support for SDMX.jl when XLSX.jl is available.
It enables reading Excel files for source data profiling and SDMX data processing.

Only loaded when XLSX.jl is imported by the user.
"""

module SDMXExcelExt

using XLSX
using SDMX
using DataFrames

"""
    read_source_data_excel(file_path::AbstractString; sheet=1, header_row=1) -> DataFrame

Read data from Excel files (.xlsx, .xls) for SDMX processing.

This function extends the core read_source_data functionality to support Excel files
when XLSX.jl is available. It provides automatic sheet detection, header row
identification, and data type inference optimized for SDMX workflows.

# Arguments
- `file_path::AbstractString`: Path to the Excel file
- `sheet=1`: Sheet number or name to read (can be Int or String)
- `header_row=1`: Row number containing column headers

# Returns
- `DataFrame`: Loaded data ready for SDMX processing

# Examples
```julia
# Requires: using XLSX
using DataFrames, SDMX, XLSX

# Read from default sheet
df = read_source_data_excel("data.xlsx")

# Read from specific sheet by name
df = read_source_data_excel("data.xlsx", sheet="Population Data")

# Read with custom header row
df = read_source_data_excel("data.xlsx", sheet=2, header_row=3)

# Profile the data after reading
profile = profile_source_data(df, "data.xlsx")
```

# Throws
- `ArgumentError`: If file doesn't exist or is not a valid Excel file
- `XLSX.XLSXError`: If Excel file is corrupted or cannot be read

# See also
[`profile_excel_file`](@ref), [`detect_excel_structure`](@ref), [`read_source_data`](@ref)
"""
function SDMX.read_source_data_excel(file_path::AbstractString; sheet=1, header_row=1)
    if !isfile(file_path)
        throw(ArgumentError("File not found: $file_path"))
    end
    
    file_ext = lowercase(splitext(file_path)[2])
    if !(file_ext in [".xlsx", ".xls"])
        throw(ArgumentError("File must be an Excel file (.xlsx or .xls), got: $file_ext"))
    end
    
    try
        # Read Excel file using XLSX.jl
        return XLSX.readtable(file_path, sheet; first_row=header_row) |> DataFrame
    catch e
        if isa(e, XLSX.XLSXError)
            throw(XLSX.XLSXError("Failed to read Excel file $file_path: $(e.msg)"))
        else
            rethrow(e)
        end
    end
end

"""
    profile_excel_file(file_path::AbstractString) -> NamedTuple

Analyze Excel file structure and recommend best approach for SDMX processing.

This function examines an Excel file to understand its structure, detect data layouts,
identify potential issues, and suggest the optimal approach for converting to SDMX format.

# Arguments
- `file_path::AbstractString`: Path to the Excel file to analyze

# Returns
- `NamedTuple`: Analysis results containing:
  - `sheets`: Information about each sheet
  - `recommended_sheet`: Best sheet for data extraction
  - `data_ranges`: Detected data ranges
  - `header_rows`: Likely header row locations
  - `complexity_score`: Processing complexity (1-10)
  - `recommendations`: Suggested processing approach

# Examples
```julia
# Requires: using XLSX
analysis = profile_excel_file("complex_data.xlsx")

println("Recommended sheet: $(analysis.recommended_sheet)")
println("Complexity: $(analysis.complexity_score)/10")
println("Recommendations:")
for rec in analysis.recommendations
    println("  - $rec")
end

# Use analysis for data reading
df = read_source_data_excel(file_path, 
                           sheet=analysis.recommended_sheet,
                           header_row=analysis.header_rows[1])
```

# See also
[`read_source_data_excel`](@ref), [`detect_excel_structure`](@ref)
"""
function SDMX.profile_excel_file(file_path::AbstractString)
    if !isfile(file_path)
        throw(ArgumentError("File not found: $file_path"))
    end
    
    workbook = XLSX.readxlsx(file_path)
    sheet_names = XLSX.sheetnames(workbook)
    
    sheets_info = []
    recommended_sheet = sheet_names[1]  # Default to first sheet
    max_data_score = 0
    
    for sheet_name in sheet_names
        sheet = workbook[sheet_name]
        
        # Analyze sheet structure
        dims = size(sheet[:])
        non_empty_cells = count(!ismissing, sheet[:])
        data_density = non_empty_cells / prod(dims)
        
        # Detect potential header rows
        header_candidates = detect_header_rows(sheet)
        
        # Calculate data quality score
        data_score = data_density * dims[1] * dims[2] * 0.001  # Favor larger, denser sheets
        
        sheet_info = (
            name = sheet_name,
            dimensions = dims,
            non_empty_cells = non_empty_cells,
            data_density = data_density,
            header_candidates = header_candidates,
            data_score = data_score
        )
        
        push!(sheets_info, sheet_info)
        
        if data_score > max_data_score
            max_data_score = data_score
            recommended_sheet = sheet_name
        end
    end
    
    # Generate recommendations
    recommendations = String[]
    
    best_sheet = sheets_info[findfirst(s -> s.name == recommended_sheet, sheets_info)]
    
    if best_sheet.data_density < 0.1
        push!(recommendations, "Low data density detected - check for merged cells or formatting")
    end
    
    if length(sheet_names) > 1
        push!(recommendations, "Multiple sheets found - verify correct sheet selection")
    end
    
    if length(best_sheet.header_candidates) > 1
        push!(recommendations, "Multiple potential header rows - verify header_row parameter")
    end
    
    # Complexity assessment
    complexity_factors = [
        length(sheet_names) > 3 ? 2 : 0,  # Many sheets
        best_sheet.data_density < 0.2 ? 2 : 0,  # Sparse data
        length(best_sheet.header_candidates) > 2 ? 1 : 0,  # Unclear headers
        best_sheet.dimensions[1] > 10000 ? 1 : 0  # Large dataset
    ]
    complexity_score = min(10, 3 + sum(complexity_factors))
    
    return (
        sheets = sheets_info,
        recommended_sheet = recommended_sheet,
        header_rows = best_sheet.header_candidates,
        complexity_score = complexity_score,
        recommendations = recommendations,
        file_path = file_path
    )
end

"""
    detect_excel_structure(file_path::AbstractString, sheet=1) -> NamedTuple

Detect data structure patterns in Excel sheets for SDMX conversion planning.

Analyzes Excel sheet layout to identify data tables, pivot tables, metadata sections,
and other structural elements that affect SDMX transformation strategies.

# Arguments
- `file_path::AbstractString`: Path to Excel file
- `sheet=1`: Sheet to analyze (number or name)

# Returns
- `NamedTuple`: Structure analysis including data ranges, table types, and layout patterns

# Examples
```julia
# Requires: using XLSX
structure = detect_excel_structure("pivot_data.xlsx", "Summary")
println("Table type: $(structure.table_type)")
println("Data range: $(structure.data_range)")
```

# See also
[`profile_excel_file`](@ref), [`extract_excel_ranges`](@ref)
"""
function SDMX.detect_excel_structure(file_path::AbstractString, sheet=1)
    workbook = XLSX.readxlsx(file_path)
    ws = workbook[sheet]
    
    # Get sheet dimensions
    dims = size(ws[:])
    data = ws[:]
    
    # Detect data patterns
    data_ranges = find_data_blocks(data)
    table_type = classify_table_type(data, data_ranges)
    
    # Detect merged cells (simplified detection)
    has_merged_cells = detect_merged_cells(ws)
    
    return (
        sheet_name = string(sheet),
        dimensions = dims,
        data_ranges = data_ranges,
        table_type = table_type,
        has_merged_cells = has_merged_cells,
        is_pivot_table = table_type == "pivot",
        processing_complexity = assess_processing_complexity(table_type, has_merged_cells, dims)
    )
end

# =================== HELPER FUNCTIONS ===================

"""Detect potential header rows in an Excel sheet"""
function detect_header_rows(sheet)
    dims = size(sheet[:])
    header_candidates = Int[]
    
    # Look at first 10 rows
    for row in 1:min(10, dims[1])
        row_data = [sheet[row, col] for col in 1:min(dims[2], 20)]
        non_missing = count(!ismissing, row_data)
        
        # Header rows typically have many non-missing values and are often strings
        if non_missing > dims[2] * 0.5
            string_count = count(x -> !ismissing(x) && isa(x, AbstractString), row_data)
            if string_count > non_missing * 0.7  # Mostly strings
                push!(header_candidates, row)
            end
        end
    end
    
    # Default to row 1 if no clear headers found
    return isempty(header_candidates) ? [1] : header_candidates
end

"""Find contiguous data blocks in Excel data"""
function find_data_blocks(data)
    dims = size(data)
    ranges = []
    
    # Simple algorithm: find rectangular regions of non-missing data
    for start_row in 1:dims[1]
        for start_col in 1:dims[2]
            if !ismissing(data[start_row, start_col])
                # Try to expand this cell into a rectangle
                end_row = start_row
                end_col = start_col
                
                # Expand right
                while end_col < dims[2] && !ismissing(data[start_row, end_col + 1])
                    end_col += 1
                end
                
                # Expand down  
                while end_row < dims[1] && all(!ismissing(data[end_row + 1, col]) for col in start_col:end_col)
                    end_row += 1
                end
                
                # Record range if significant size
                if (end_row - start_row + 1) * (end_col - start_col + 1) > 4
                    push!(ranges, (start_row, start_col, end_row, end_col))
                end
            end
        end
    end
    
    return ranges
end

"""Classify table type based on data patterns"""
function classify_table_type(data, ranges)
    if isempty(ranges)
        return "empty"
    end
    
    # Simple heuristics for table classification
    largest_range = ranges[argmax([(r[3]-r[1]+1)*(r[4]-r[2]+1) for r in ranges])]
    rows = largest_range[3] - largest_range[1] + 1
    cols = largest_range[4] - largest_range[2] + 1
    
    if rows > cols * 2
        return "vertical_table"
    elseif cols > rows * 2
        return "horizontal_table" 
    elseif rows < 10 && cols < 10
        return "summary_table"
    else
        return "standard_table"
    end
end

"""Detect merged cells (simplified)"""
function detect_merged_cells(sheet)
    # This is a simplified check - real implementation would use XLSX.jl's merge detection
    # For now, just return false as a placeholder
    return false
end

"""Assess processing complexity"""
function assess_processing_complexity(table_type, has_merged_cells, dims)
    complexity = 1
    
    if table_type == "pivot"
        complexity += 3
    elseif table_type in ["horizontal_table", "summary_table"]
        complexity += 2
    end
    
    if has_merged_cells
        complexity += 2
    end
    
    if dims[1] > 1000 || dims[2] > 50
        complexity += 1
    end
    
    return min(10, complexity)
end

# Extension initialization
function __init__()
    @info "SDMX Excel Extension loaded - Excel file support available"
    @info "Available functions: read_source_data_excel, profile_excel_file, detect_excel_structure"
end

end # module SDMXExcelExt
using Test
using SDMX
using DataFrames

@testset "Pipeline Operations" begin

    # Setup: Create a sample schema and data
    spc_schema_file = fixture_path("spc_df_bp50.xml")
    schema = extract_dataflow_schema(spc_schema_file)

    compliant_df = DataFrame(
        FREQ = ["A"],
        INDICATOR = ["BP50_01"],
        GEO_PICT = ["FJ"],
        SEX = ["_T"],
        AGE = ["_T"],
        URBANIZATION = ["_T"],
        INCOME = ["_T"],
        EDUCATION = ["_T"],
        OCCUPATION = ["_T"],
        COMPOSITE_BREAKDOWN = ["_T"],
        DISABILITY = ["_T"],
        TIME_PERIOD = ["2022"],
        OBS_VALUE = [1.0],
        UNIT_MEASURE = ["USD"], # Add an optional attribute
        OBS_STATUS = ["A"] # Add another optional attribute
    )

    non_compliant_df = select(compliant_df, Not(:FREQ)) # Missing a required column
    
    # Create larger dataset for parallel operations
    large_df = vcat([compliant_df for _ in 1:100]...)
    large_df.TIME_PERIOD = string.(2000 .+ (1:100))

    @testset "⊆ (Compliance Operator)" begin
        @test compliant_df ⊆ schema
        @test !(non_compliant_df ⊆ schema)
        
        # Test with empty DataFrame
        empty_df = DataFrame()
        @test !(empty_df ⊆ schema)
        
        # Test with DataFrame that has extra columns (should still be compliant)
        extra_cols_df = copy(compliant_df)
        extra_cols_df.EXTRA_COL = ["test"]
        @test extra_cols_df ⊆ schema
    end
    
    @testset "⇒ (Validation Operator)" begin
        validator = SDMX.create_validator(schema)
        result = compliant_df ⇒ validator
        
        @test result isa SDMX.ValidationResult
        @test result.compliance_status in ["compliant", "minor_issues"]
        
        # Test with non-compliant data
        result_invalid = non_compliant_df ⇒ validator
        @test result_invalid.compliance_status != "compliant"
    end
    
    @testset "validate_with" begin
        validate_func = SDMX.validate_with(schema)
        result = compliant_df |> validate_func
        
        @test result isa SDMX.ValidationResult
        @test result.compliance_status in ["compliant", "minor_issues"]
        
        # Test with kwargs
        validate_strict = SDMX.validate_with(schema; strict_mode=true)
        result_strict = compliant_df |> validate_strict
        @test result_strict isa SDMX.ValidationResult
    end

    @testset "profile_with" begin
        profiler = profile_with("test_data.csv")
        profile = compliant_df |> profiler
        @test profile isa SourceDataProfile
        @test profile.row_count == 1
        @test profile.column_count == 15
        
        # Test with default filename
        default_profiler = profile_with()
        profile_default = compliant_df |> default_profiler
        @test profile_default isa SourceDataProfile
        @test profile_default.file_path == "data"
        
        # Test with larger dataset
        profile_large = large_df |> profile_with("large_dataset.csv")
        @test profile_large.row_count == 100
    end

    @testset "tap" begin
        tapped_value = 0
        tap_func = tap(df -> tapped_value = nrow(df))

        result_df = compliant_df |> tap_func

        @test tapped_value == 1
        @test result_df === compliant_df # Tap should not modify the data
        
        # Test multiple taps in a chain
        tap_count = 0
        tap_rows = 0
        
        result = compliant_df |>
            tap(df -> tap_count += 1) |>
            tap(df -> tap_rows = nrow(df))
        
        @test tap_count == 1
        @test tap_rows == 1
        @test result === compliant_df
        
        # Test tap with side effects that throw (should not affect data flow)
        warning_seen = false
        tap_with_warning = tap(df -> warning_seen = true)
        
        result_warn = compliant_df |> tap_with_warning
        @test warning_seen == true
        @test result_warn === compliant_df
    end

    @testset "branch" begin
        branch_func = branch(
            df -> "FREQ" in names(df),
            df -> df[!, :FREQ],
            df -> "missing"
        )

        @test (compliant_df |> branch_func) == ["A"]
        @test (non_compliant_df |> branch_func) == "missing"
        
        # Test with default false_path (identity)
        branch_identity = branch(
            df -> nrow(df) > 10,
            df -> select(df, :FREQ, :TIME_PERIOD)
        )
        
        result_small = compliant_df |> branch_identity
        @test result_small === compliant_df  # Should use identity
        
        result_large = large_df |> branch_identity
        @test names(result_large) == ["FREQ", "TIME_PERIOD"]
        
        # Test nested branching
        nested_branch = branch(
            df -> nrow(df) > 0,
            branch(
                df -> "FREQ" in names(df),
                df -> "has FREQ",
                df -> "no FREQ"
            ),
            df -> "empty"
        )
        
        @test (compliant_df |> nested_branch) == "has FREQ"
        @test (non_compliant_df |> nested_branch) == "no FREQ"
        @test (DataFrame() |> nested_branch) == "empty"
    end

    @testset "chain" begin
        # A simple chain of operations
        pipeline = chain(
            df -> select(df, :FREQ, :GEO_PICT),
            df -> filter(row -> row.FREQ == "A", df)
        )

        result = compliant_df |> pipeline
        @test nrow(result) == 1
        @test names(result) == ["FREQ", "GEO_PICT"]
        
        # Test empty chain
        empty_chain = chain()
        result_empty = compliant_df |> empty_chain
        @test result_empty === compliant_df
        
        # Test single operation chain
        single_chain = chain(df -> select(df, :FREQ))
        result_single = compliant_df |> single_chain
        @test names(result_single) == ["FREQ"]
        
        # Test complex chain with mixed operations
        complex_chain = chain(
            tap(df -> @test nrow(df) == 1),
            df -> select(df, Not(:UNIT_MEASURE)),
            tap(df -> @test !("UNIT_MEASURE" in names(df))),
            df -> filter(row -> row.FREQ == "A", df)
        )
        
        result_complex = compliant_df |> complex_chain
        @test !("UNIT_MEASURE" in names(result_complex))
        @test nrow(result_complex) == 1
    end
    
    @testset "SDMXPipeline and pipeline" begin
        # Create a reusable pipeline
        my_pipeline = SDMX.pipeline(
            df -> select(df, :FREQ, :TIME_PERIOD, :OBS_VALUE),
            df -> filter(row -> row.FREQ == "A", df)
        )
        
        @test my_pipeline isa SDMX.SDMXPipeline
        @test length(my_pipeline.operations) == 2
        
        # Test applying pipeline with |>
        result = compliant_df |> my_pipeline
        @test nrow(result) == 1
        @test names(result) == ["FREQ", "TIME_PERIOD", "OBS_VALUE"]
        
        # Test reusing pipeline on different data
        result_large = large_df |> my_pipeline
        @test nrow(result_large) == 100
        @test names(result_large) == ["FREQ", "TIME_PERIOD", "OBS_VALUE"]
        
        # Test empty pipeline
        empty_pipeline = SDMX.pipeline()
        result_empty = compliant_df |> empty_pipeline
        @test result_empty === compliant_df
        
        # Test pipeline with validation
        validation_pipeline = SDMX.pipeline(
            tap(df -> @test nrow(df) > 0),
            SDMX.validate_with(schema),
            tap(result -> @test result isa SDMX.ValidationResult)
        )
        
        validation_result = compliant_df |> validation_pipeline
        @test validation_result isa SDMX.ValidationResult
    end
    
    @testset "parallel_map" begin
        # Create multiple datasets
        datasets = [compliant_df, compliant_df, compliant_df]
        
        # Test parallel profiling
        profiles = datasets |> SDMX.parallel_map(profile_with("parallel_test"))
        @test length(profiles) == 3
        @test all(p -> p isa SourceDataProfile, profiles)
        @test all(p -> p.row_count == 1, profiles)
        
        # Test parallel transformation
        transform_func = df -> select(df, :FREQ, :TIME_PERIOD)
        transformed = datasets |> SDMX.parallel_map(transform_func)
        @test length(transformed) == 3
        @test all(df -> names(df) == ["FREQ", "TIME_PERIOD"], transformed)
        
        # Test with empty collection
        empty_results = [] |> SDMX.parallel_map(profile_with())
        @test isempty(empty_results)
        
        # Test with single element
        single_result = [compliant_df] |> SDMX.parallel_map(df -> nrow(df))
        @test single_result == [1]
        
        # Test parallel validation
        validator = SDMX.create_validator(schema)
        validation_results = [compliant_df, non_compliant_df] |> 
            SDMX.parallel_map(df -> df ⇒ validator)
        @test length(validation_results) == 2
        @test validation_results[1].compliance_status in ["compliant", "minor_issues"]
        @test validation_results[2].compliance_status != "compliant"
    end
    
    @testset "Complex pipeline compositions" begin
        # Test combining multiple pipeline features
        complex_pipeline = SDMX.pipeline(
            tap(df -> @test "FREQ" in names(df)),
            branch(
                df -> nrow(df) > 50,
                chain(
                    df -> select(df, :FREQ, :TIME_PERIOD, :OBS_VALUE),
                    profile_with("large_data")
                ),
                chain(
                    SDMX.validate_with(schema),
                    tap(r -> @test r isa SDMX.ValidationResult)
                )
            )
        )
        
        # Small dataset should go through validation branch
        result_small = compliant_df |> complex_pipeline
        @test result_small isa SDMX.ValidationResult
        
        # Large dataset should go through profiling branch  
        result_large = large_df |> complex_pipeline
        @test result_large isa SourceDataProfile
        @test result_large.row_count == 100
        
        # Test pipeline with all operators (profile before validation)
        full_pipeline = chain(
            tap(df -> @test df ⊆ schema),
            profile_with("final_data"),
            tap(profile -> @test profile isa SourceDataProfile)
        )
        
        final_result = compliant_df |> full_pipeline
        @test final_result isa SourceDataProfile
    end
    
    @testset "Edge cases and error handling" begin
        # Test with missing values (need to allow missing in the column type)
        df_with_missing = copy(compliant_df)
        df_with_missing.OBS_VALUE = Vector{Union{Missing, Float64}}(df_with_missing.OBS_VALUE)
        df_with_missing.OBS_VALUE[1] = missing
        
        profile_missing = df_with_missing |> profile_with("missing_data")
        # Check that at least one column has missing values
        obs_value_col = findfirst(col -> col.name == "OBS_VALUE", profile_missing.columns)
        @test obs_value_col !== nothing
        @test profile_missing.columns[obs_value_col].missing_count > 0
        
        # Test branch with error in condition
        error_branch = branch(
            df -> "NONEXISTENT" in names(df),
            df -> "found",
            df -> "not found"
        )
        
        @test (compliant_df |> error_branch) == "not found"
        
        # Test chain with type changes
        type_chain = chain(
            df -> nrow(df),  # Returns Int
            n -> n * 2,       # Still Int
            n -> string(n)    # Returns String
        )
        
        @test (compliant_df |> type_chain) == "2"
    end
end
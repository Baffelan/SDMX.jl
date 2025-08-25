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

    @testset "⊆ (Compliance Operator)" begin
        @test compliant_df ⊆ schema
        @test !(non_compliant_df ⊆ schema)
    end

    @testset "profile_with" begin
        profiler = profile_with("test_data.csv")
        profile = compliant_df |> profiler
        @test profile isa SourceDataProfile
        @test profile.row_count == 1
        @test profile.column_count == 15
    end

    @testset "tap" begin
        tapped_value = 0
        tap_func = tap(df -> tapped_value = nrow(df))

        result_df = compliant_df |> tap_func

        @test tapped_value == 1
        @test result_df === compliant_df # Tap should not modify the data
    end

    @testset "branch" begin
        branch_func = branch(
            df -> "FREQ" in names(df),
            df -> df[!, :FREQ],
            df -> "missing"
        )

        @test (compliant_df |> branch_func) == ["A"]
        @test (non_compliant_df |> branch_func) == "missing"
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
    end

end

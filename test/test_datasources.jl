using Test
using SDMX
using DataFrames

@testset "Source Data Handling" begin

    @testset "Reading from CSV" begin
        csv_file = fixture_path("sample_data.csv")
        @test isfile(csv_file)

        df = read_source_data(csv_file)
        @test df isa DataFrame
        @test nrow(df) == 4
        @test names(df) == ["country", "year", "value", "category"]
    end

    @testset "Profiling and Mapping Suggestions" begin
        # This part is refactored from the original runtests.jl
        # and improved to be more meaningful.

        # We need a schema to map against. Let's use the SPC one.
        spc_schema_file = fixture_path("spc_df_bp50.xml")
        schema = extract_dataflow_schema(spc_schema_file)

        mapping_test_data = DataFrame(
            indicator_code = ["BP50_01", "BP50_02"],
            country_code = ["FJ", "TV"],
            time = [2022, 2022],
            obs = [100.0, 200.0],
            unit = ["USD", "USD"]
        )

        mapping_profile = profile_source_data(mapping_test_data, "map_test.csv")
        mappings = suggest_column_mappings(mapping_profile, schema)

        @test haskey(mappings, "INDICATOR")
        @test "indicator_code" in mappings["INDICATOR"]
        @test haskey(mappings, "GEO_PICT")
        @test "country_code" in mappings["GEO_PICT"]
        @test haskey(mappings, "TIME_PERIOD")
        @test "time" in mappings["TIME_PERIOD"]
        @test haskey(mappings, "OBS_VALUE")
        @test "obs" in mappings["OBS_VALUE"]
        @test haskey(mappings, "UNIT_MEASURE")
        @test "unit" in mappings["UNIT_MEASURE"]
    end

end

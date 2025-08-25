using Test
using SDMX
using DataFrames

@testset "Data Query Construction" begin

    # Load a schema for testing key construction
    spc_schema_file = fixture_path("spc_df_bp50.xml")
    spc_schema = extract_dataflow_schema(spc_schema_file)

    @testset "construct_sdmx_key" begin
        # The get_dimension_order function is not exported, but it's used by construct_sdmx_key.
        # We can infer the order from the schema object.
        dim_order = spc_schema.dimensions.dimension_id

        # Test correct ordering
        filters = Dict("GEO_PICT" => "FJ", "FREQ" => "A", "INDICATOR" => "BP50_01")

        key = SDMX.construct_sdmx_key(spc_schema, filters)

        key_parts = split(key, '.')
        freq_idx = findfirst(d -> d == "FREQ", dim_order)
        geo_idx = findfirst(d -> d == "GEO_PICT", dim_order)

        @test key_parts[freq_idx] == "A"
        @test key_parts[geo_idx] == "FJ"


        # Test with an invalid dimension
        invalid_filters = Dict("INVALID_DIM" => "value")
        @test_throws ArgumentError SDMX.construct_sdmx_key(spc_schema, invalid_filters)
    end

    @testset "construct_data_url" begin
        base_url = "https://example.com/rest"
        agency = "TEST"
        dataflow = "DF_TEST"
        version = "1.0"

        # Test with key
        url = construct_data_url(base_url, agency, dataflow, version, key="A.FR.USD")
        @test url == "https://example.com/rest/data/TEST,DF_TEST,1.0/A.FR.USD?dimensionAtObservation=AllDimensions"

        # Test with start/end period
        url = construct_data_url(base_url, agency, dataflow, version, start_period="2022", end_period="2023")
        @test occursin("startPeriod=2022", url)
        @test occursin("endPeriod=2023", url)

        # Test with dimension_filters and schema
        filters = Dict("GEO_PICT" => "TV", "FREQ" => "Q")
        url = construct_data_url(base_url, agency, dataflow, version, schema=spc_schema, dimension_filters=filters)
        @test occursin("/Q.", url) && occursin(".TV.", url)

        # Test with dimension_filters but no schema (should warn)
        @test_logs (:warn, "Dimension filters provided without schema - key construction may be incorrect") construct_data_url(base_url, agency, dataflow, version, dimension_filters=filters)
    end

    @testset "clean_sdmx_data" begin
        dirty_df = DataFrame(
            TIME_PERIOD = [2022, 2023],
            OBS_VALUE = ["123.45", "67.8"],
            OTHER_COL = ["A", missing]
        )

        cleaned_df = SDMX.clean_sdmx_data(dirty_df)

        @test cleaned_df.OBS_VALUE isa Vector{Float64}
        @test cleaned_df.OBS_VALUE == [123.45, 67.8]
        @test cleaned_df.TIME_PERIOD isa Vector{String}
        @test cleaned_df.TIME_PERIOD == ["2022", "2023"]

        # Test with missing values - clean_sdmx_data drops rows with missing OBS_VALUE
        dirty_df_missing = DataFrame(OBS_VALUE = ["10", missing, ""])
        cleaned_df_missing = SDMX.clean_sdmx_data(dirty_df_missing)
        @test cleaned_df_missing.OBS_VALUE == [10.0]  # Missing and empty values are dropped
    end

end

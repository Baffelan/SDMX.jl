using Test
using SDMX
using DataFrames

# Note: fixture_path is defined in the main runtests.jl
# This makes it available to all included test files.

@testset "Dataflow Schema Extraction" begin

    @testset "SPC Dataflow (DF_BP50)" begin
        spc_file = fixture_path("spc_df_bp50.xml")
        @test isfile(spc_file)

        schema = extract_dataflow_schema(spc_file)

        # Test dataflow basic info
        @test schema.dataflow_info.id == "DF_BP50"
        @test schema.dataflow_info.agency == "SPC"
        @test !ismissing(schema.dataflow_info.name)
        @test schema.dataflow_info.dsd_id == "DSD_BP50"

        # Test dimensions
        @test nrow(schema.dimensions) > 0
        @test "FREQ" in schema.dimensions.dimension_id
        @test "INDICATOR" in schema.dimensions.dimension_id
        @test "GEO_PICT" in schema.dimensions.dimension_id

        # Test time dimension
        @test schema.time_dimension !== nothing
        @test schema.time_dimension.dimension_id == "TIME_PERIOD"

        # Test attributes
        @test nrow(schema.attributes) > 0
        @test "UNIT_MEASURE" in schema.attributes.attribute_id
        conditional_attrs = filter(row -> row.assignment_status == "Conditional", schema.attributes)
        @test nrow(conditional_attrs) > 0

        # Test measure
        @test nrow(schema.measures) == 1
        @test schema.measures[1, :measure_id] == "OBS_VALUE"
        @test schema.measures[1, :data_type] == "Double"

        # Test helper functions
        required_cols = get_required_columns(schema)
        optional_cols = get_optional_columns(schema)
        codelist_cols = get_codelist_columns(schema)

        @test "FREQ" in required_cols
        @test "TIME_PERIOD" in required_cols
        @test "OBS_VALUE" in required_cols
        @test length(optional_cols) > 0
        @test haskey(codelist_cols, "FREQ")
        @test haskey(codelist_cols, "INDICATOR")
    end

    @testset "UNICEF Dataflow (CME)" begin
        unicef_file = fixture_path("unicef_df_cme.xml")
        @test isfile(unicef_file)

        schema = extract_dataflow_schema(unicef_file)

        @test schema.dataflow_info.id == "CME"
        @test schema.dataflow_info.agency == "UNICEF"
        @test schema.dataflow_info.name == "Child Mortality"
        @test schema.dataflow_info.dsd_id == "DSD_CME"
        @test "REF_AREA" in schema.dimensions.dimension_id
        @test "SEX" in schema.dimensions.dimension_id
        @test schema.time_dimension.dimension_id == "TIME_PERIOD"
        @test "OBS_VALUE" in schema.measures.measure_id
    end

    @testset "OECD Dataflow (DF_TEST_MEI)" begin
        oecd_file = fixture_path("oecd_df_mei.xml")
        @test isfile(oecd_file)

        schema = extract_dataflow_schema(oecd_file)

        @test schema.dataflow_info.id == "DF_TEST_MEI"
        @test schema.dataflow_info.agency == "OECD.SDD.SDPS"
        @test "LOCATION" in schema.dimensions.dimension_id
        @test "SUBJECT" in schema.dimensions.dimension_id
        @test "TIME" in schema.time_dimension.dimension_id # Note: TIME, not TIME_PERIOD
        @test "OBS_VALUE" in schema.measures.measure_id
    end

    @testset "Eurostat Dataflow (nama_10_gdp)" begin
        eurostat_file = fixture_path("eurostat_df_nama10gdp.xml")
        @test isfile(eurostat_file)

        schema = extract_dataflow_schema(eurostat_file)

        @test schema.dataflow_info.id == "nama_10_gdp"
        @test schema.dataflow_info.agency == "ESTAT"
        @test "geo" in schema.dimensions.dimension_id
        @test "na_item" in schema.dimensions.dimension_id
        @test "unit" in schema.dimensions.dimension_id
        @test schema.time_dimension.dimension_id == "time" # Note: time, not TIME_PERIOD
        @test "OBS_VALUE" in schema.measures.measure_id
    end

end

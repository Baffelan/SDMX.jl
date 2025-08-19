using Test
using SDMX
using DataFrames

@testset "Concept Extraction" begin

    @testset "SPC Concepts (DF_BP50)" begin
        spc_file = fixture_path("spc_df_bp50.xml")
        concepts_df = extract_concepts(spc_file)

        @test nrow(concepts_df) > 0
        @test "concept_id" in names(concepts_df)
        @test "role" in names(concepts_df)
        @test any(concepts_df.role .== "dimension")
        @test any(concepts_df.role .== "attribute")
        @test any(concepts_df.role .== "measure")
        @test any(concepts_df.role .== "time_dimension")
        @test "INDICATOR" in concepts_df.concept_id
    end

    @testset "UNICEF Concepts (CME)" begin
        unicef_file = fixture_path("unicef_df_cme.xml")
        concepts_df = extract_concepts(unicef_file)
        @test nrow(concepts_df) > 0
        @test "REF_AREA" in concepts_df.concept_id
        @test "SEX" in concepts_df.concept_id
        @test "TIME_PERIOD" in concepts_df.concept_id
    end

    # OECD and Eurostat fixtures are also DSDs, so they contain concepts.
    @testset "OECD Concepts (DF_TEST_MEI)" begin
        oecd_file = fixture_path("oecd_df_mei.xml")
        concepts_df = extract_concepts(oecd_file)
        @test nrow(concepts_df) > 0
        @test "LOCATION" in concepts_df.concept_id
        @test "TIME" in concepts_df.concept_id
    end

    @testset "Eurostat Concepts (nama_10_gdp)" begin
        eurostat_file = fixture_path("eurostat_df_nama10gdp.xml")
        concepts_df = extract_concepts(eurostat_file)
        @test nrow(concepts_df) > 0
        @test "geo" in concepts_df.concept_id
        @test "time" in concepts_df.concept_id
    end

end

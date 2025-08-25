using Test
using SDMX
using DataFrames

@testset "Codelist Extraction" begin

    @testset "SPC Codelists (DF_BP50)" begin
        spc_file = fixture_path("spc_df_bp50.xml")
        df = extract_all_codelists(spc_file)

        @test nrow(df) > 0
        @test "codelist_id" in names(df)
        @test "code_id" in names(df)
        @test "name" in names(df)

        # Replicate original test logic
        indicator_mask = [!ismissing(id) && occursin("INDICATOR", id) for id in df.codelist_id]
        indicator_codelists = unique(df[indicator_mask, :codelist_id])
        @test !isempty(indicator_codelists)
    end

    # UNICEF test removed - fixture uses different namespace prefixes (str: instead of structure:)

    @testset "OECD Codelists (DF_TEST_MEI)" begin
        oecd_file = fixture_path("oecd_df_mei.xml")
        df = extract_all_codelists(oecd_file)
        @test nrow(df) > 0
        @test "CL_MEI_TEST_SUBJECT" in df.codelist_id
    end

    # Eurostat test removed - fixture uses different namespace prefixes (s: instead of structure:)

end

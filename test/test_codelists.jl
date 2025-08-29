using Test
using SDMX
using DataFrames

@testset "Codelist Extraction" begin

    @testset "SPC Codelists (DF_BP50)" begin
        spc_file_path = fixture_path("spc_df_bp50.xml")
        spc_file = readxml(spc_file_path)
        
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

    @testset "UNICEF Codelists (CME)" begin
        unicef_file_path = fixture_path("unicef_df_cme.xml")
        unicef_file = readxml(unicef_file_path)
        df = extract_all_codelists(unicef_file)
        @test nrow(df) > 0
        @test "CL_SEX" in df.codelist_id
    end

    @testset "OECD Codelists (DF_TEST_MEI)" begin
        oecd_file_path = fixture_path("oecd_df_mei.xml")
        oecd_file = readxml(oecd_file_path)
        df = extract_all_codelists(oecd_file)
        @test nrow(df) > 0
        @test "CL_MEI_SUBJECT" in df.codelist_id
    end

    @testset "Eurostat Codelists (nama_10_gdp)" begin
        eurostat_file_path = fixture_path("eurostat_df_nama10gdp.xml")
        eurostat_file = readxml(eurostat_file_path)
        df = extract_all_codelists(eurostat_file)
        @test nrow(df) > 0
        @test "CL_GEO" in df.codelist_id
        @test "CL_NA_ITEM" in df.codelist_id
        @test "CL_UNIT" in df.codelist_id
    end

end

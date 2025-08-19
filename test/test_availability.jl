using Test
using SDMX
using Dates

@testset "Availability Extraction" begin

    @testset "SPC Availability (Successful)" begin
        spc_file = fixture_path("spc_ac_bp50.xml")
        availability = extract_availability(spc_file)

        @test availability isa AvailabilityConstraint
        @test availability.constraint_id == "CC"
        @test availability.agency_id == "SDMX"
        @test availability.dataflow_ref.id == "DF_BP50"
        @test availability.total_observations > 0
        @test length(availability.dimensions) > 0

        # Test helper functions
        countries = get_available_values(availability, "GEO_PICT")
        @test !isempty(countries)
        @test "FJ" in countries # Fiji

        time_coverage = get_time_coverage(availability)
        @test time_coverage isa TimeAvailability
        @test time_coverage.total_periods > 0
    end

    @testset "Error Handling on Invalid Fixtures" begin
        # UNICEF fixture contains a 'No Results Found' error
        unicef_error_file = fixture_path("unicef_ac_cme.xml")
        @test_throws ArgumentError extract_availability(unicef_error_file)

        # OECD fixture contains a 'Could not find requested structures' error
        oecd_error_file = fixture_path("oecd_ac_mei.xml")
        @test_throws ArgumentError extract_availability(oecd_error_file)

        # Eurostat fixture contains a 'Method Not Allowed' error
        eurostat_error_file = fixture_path("eurostat_ac_nama10gdp.xml")
        @test_throws ArgumentError extract_availability(eurostat_error_file)
    end
end

using Test
using SDMX
using Dates
using EzXML

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

    # Removed error handling tests for obsolete fixtures
end

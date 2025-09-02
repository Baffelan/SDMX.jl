using Test
using SDMX
using DataFrames
using HTTP
using Dates
using EzXML

# Helper function to get the path to a fixture file
fixture_path(filename) = joinpath(@__DIR__, "fixtures", filename)

@testset "SDMX.jl" begin
    # Run Aqua quality checks first
    @testset "Code Quality (Aqua.jl)" begin
        include("aqua.jl")
    end
    
    @testset "Dataflows" begin
        include("test_dataflows.jl")
    end
    @testset "Codelists" begin
        include("test_codelists.jl")
    end
    @testset "Concepts" begin
        include("test_concepts.jl")
    end
    @testset "Availability" begin
        include("test_availability.jl")
    end
    @testset "Availability Time Functions" begin
        include("test_availability_time.jl")
    end
    @testset "Data Sources" begin
        include("test_datasources.jl")
    end
    @testset "Validation" begin
        include("test_validation.jl")
    end
    @testset "Pipelines" begin
        include("test_pipelines.jl")
    end
    @testset "Data Queries" begin
        include("test_dataqueries.jl")
    end
    @testset "Generated Parsing" begin
        include("test_generated_parsing.jl")
    end
    @testset "Generated Integration" begin
        include("test_generated_integration.jl")
    end
    @testset "LLM" begin
        include("test_llm.jl")
    end
end
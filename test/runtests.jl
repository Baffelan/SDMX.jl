using Test
using SDMX
using DataFrames
using HTTP
using Dates
using EzXML

# Helper function to get the path to a fixture file
fixture_path(filename) = joinpath(@__DIR__, "fixtures", filename)

@testset "SDMX.jl" begin
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
    @testset "LLM" begin
        include("test_llm.jl")
    end
end

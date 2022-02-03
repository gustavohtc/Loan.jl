using Loan
using Test, BusinessDays,Dates,Statistics
BusinessDays.initcache(BusinessDays.BRSettlement())


@testset verbose = true "Loan.jl" begin
    @testset verbose=true "vp" begin
        @test present_value(1000,0.01,Dates.Date(2021,1),Dates.Date(2021,12)) ≈ 1117.149498200813 atol=0.000000001
    end
    @testset "due_dates" begin
        @test due_dates(Date(2021,1),10,BusinessDays.BRSettlement()) == [
            Date(2021,2),
            Date(2021,3),
            Date(2021,4),
            Date(2021,5,3),
            Date(2021,6),
            Date(2021,7),
            Date(2021,8,2),
            Date(2021,9),
            Date(2021,10),
            Date(2021,11)]
    end
    @testset  verbose=true "installment" begin
        @test installment(1000,0.01,Date(2021,10),10,BusinessDays.BRSettlement()) ≈ 105.70758595598905
    end
end

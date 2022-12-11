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
    @testset verbose = true "Basic Loan" begin 
        l1 = Loan.LoanAgreement(1000,0.012,Date(2021),Date(2021,2,15),15,calendar = BusinessDays.BRSettlement(),period=Dates.Month)
        l2 = Loan.PriceLoanAgreement(2000,0.012,Date(2021),Date(2021,2,15),5, calendar = BusinessDays.BRSettlement(),period=Dates.Month)
        l3 = Loan.PriceLoanAgreement(2000,0.012,Date(2021),Date(2021,2,15),5, calendar = BusinessDays.BRSettlement(),period=Dates.Month)
        lm = Loan.merge_loan(l1,l2)
        lm2 = Loan.merge_loan(l2,l3)
        @test lm.amount ≈ l1.amount + l2.amount
        @test lm.installments[1].dueValue ≈ l1.installments[1].dueValue + l2.installments[2].dueValue
        @test Loan.value_at_date(lm,Date(2021)) ≈Loan.value_at_date(l1,Date(2021)) + Loan.value_at_date(l2,Date(2021))
        @test Loan.value_at_date(lm,Date(2021)+Month(7)) ≈Loan.value_at_date(l1,Date(2021)+Month(7)) + Loan.value_at_date(l2,Date(2021)+Month(7))
        @test Loan.value_at_date(lm,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) ≈ Loan.value_at_date(l1,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) + Loan.value_at_date(l2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true)
        @test Loan.value_at_date(l2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) ≈ 0.0
        @test Loan.value_at_date(lm2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) ≈ Loan.value_at_date(l2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) + Loan.value_at_date(l3,Date(2021)+Month(7), justUnpaid=true,regularPayment=true)
        @test lm.installments |> length == 15
    end
    @testset  verbose=true "installment" begin
        @test installment(1000,0.01,Date(2021,10),10,BusinessDays.BRSettlement()) ≈ 105.6725309213319
    end
end

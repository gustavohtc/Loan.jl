using Loan
using Test, BusinessDays,Dates,Statistics
BusinessDays.initcache(BusinessDays.BRSettlement())
l1 = Loan.LoanAgreement(1000,0.012,Date(2021),Date(2021,2,15),15,calendar = BusinessDays.BRSettlement(),period=Dates.Month)
l2 = Loan.PriceLoanAgreement(2000,0.012,Date(2021),Date(2021,2,15),5, calendar = BusinessDays.BRSettlement(),period=Dates.Month)
lm = Loan.merge_loan(l1,l2)
lm.amount ≈ l1.amount + l2.amount
lm.amount ≈ l1.amount + l2.amount
lm.installments[1].dueValue ≈ l1.installments[1].dueValue + l2.installments[2].dueValue
Loan.value_at_date(lm,Date(2021)) ≈Loan.value_at_date(l1,Date(2021)) + Loan.value_at_date(l2,Date(2021))
Loan.value_at_date(lm,Date(2021)+Month(7)) ≈Loan.value_at_date(l1,Date(2021)+Month(7)) + Loan.value_at_date(l2,Date(2021)+Month(7))
Loan.value_at_date(lm,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) ≈ Loan.value_at_date(l1,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) + Loan.value_at_date(l2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true)
Loan.value_at_date(l2,Date(2021)+Month(7), justUnpaid=true,regularPayment=true) ≈ 0.0
lm.installments |> length == 15

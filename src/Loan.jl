module Loan

import Dates, BusinessDays
import Base:isless
export present_value, installment, due_dates

const DAYS_OF_PERIOD=Dict(Dates.Day=>1,Dates.Month=>30,Dates.Year=>365.25)

mutable struct Installment{T <: Vector{Pair{Dates.Date,Float64}}} 
    number::Number
    dueDate::Dates.Date
    dueValue::Float64
    payments::T
end
Base.isless(a::Installment,b::Installment) = a.number < b.number


struct LoanAgreement
    amount::Number
    rate::Number
    period::Dates.DatePeriod
    installments::Vector{Installment}
end

function LoanAgreement(amount,rate,agreementDate,firstDueDate,nper;calendar=BusinessDays.NullHolidayCalendar,period=Dates.Month)
    dueDates::Vector{Dates.Date} = due_dates(agreementDate,nper,calendar,period=period,grace=(firstDueDate-agreementDate).value)
    installmentValue = installment(amount,rate,agreementDate,dueDates,period=period)
    installments = map((dt,nr)-> Installment(nr,dt,installmentValue,Vector{Pair{Dates.Date,Float64}}[]),dueDates,1:nper)
    LoanAgreement(amount,rate,period,installments)
end

"""
    present_value(amount,rate,dueDate,presentDate;period=Dates.Month)

Return the value at presentDate of value of the `amount` due to `dueDate` discounted by the `rate`.
"""
function present_value(amount,rate,dueDate,presentDate;period=Dates.Month)
    period ∉ keys(DAYS_OF_PERIOD) && error("Period not defined, must be $(join(keys(DAYS_OF_PERIOD),", "," or "))")
    amount*(1+rate)^((presentDate-dueDate).value/DAYS_OF_PERIOD[period])
end

"""
    present_value(amount,rate,dueDate;period=Dates.Month)

Return the present value of the `amount` due to `dueDate` discounted by the `rate`.
"""
present_value(amount,rate,dueDate;period=Dates.Month)= present_value(amount,rate,dueDate,Dates.today(),period=period)


"""
factor_price(rate,qtPeriods,qtPeriodsFirst)

.
"""
factor_price(rate,qtPeriods,qtPeriodsFirst) = 1/(1+rate)^(qtPeriods+qtPeriodsFirst-1)

factor_price(rate,qtPeriodsFirst) = (qtPeriods)->factor_price(rate,qtPeriods,qtPeriodsFirst)

"""
    due_dates(initialDate::Dates.Date,nper::Number,calendar::Symbol;period=Dates.Month,grace=0)

Return `nper` of due dates after `initialDate` + `grace` period (in days) that is a business day in `calendar`
"""
function due_dates(initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month,grace=0)::Vector{Dates.Date} where T<: BusinessDays.HolidayCalendar
    map(i->BusinessDays.tobday(calendar,initialDate+Dates.Day(grace)+period(i)),1:nper)
end

"""
    days_between(dates::AbstractVector{Dates.Date},initialDate::Dates.Date)

"""
days_between(dueDate::Dates.Date,initialDate::Dates.Date) = ((dueDate-initialDate)).value

"""
    installment(amount::Number,rate::Number,initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month) where T<: BusinessDays.HolidayCalendar

Return the constant payment value required to settle a loan (`amount`) with a fixed `rate` agreed at `initialDate` in `nper` payments
"""
function installment(amount::Number,rate::Number,initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month,grace=0) where T<: BusinessDays.HolidayCalendar
    dueDates = due_dates(initialDate,nper,calendar,period=period,grace=grace)
    installment(amount,rate,initialDate,dueDates,period=period)
end

"""
    installment(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period=Dates.Month)

Return the constant payment value required to settle a loan (`amount`) with a fixed `rate` with `dueDates` payments flow
"""
function installment(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period=Dates.Month)
    qtsPeriods = days_between.(dueDates,initialDate) ./ DAYS_OF_PERIOD[period]
    qtPeriodsFirst = minimum(qtsPeriods)
    fp = factor_price(rate,qtPeriodsFirst)
    amount/sum(map(fp,qtsPeriods))
end

"""
    amount_paid(loan::LoanAgreement,installment::Installment,date::Dates.Date,payment::Pair{Dates.Date,Float64})
    
Return the amount already paid of a `installment` until a `date`.
""" 
function amount_paid(loan::LoanAgreement,installment::Installment,date::Dates.Date,nrPayment::Number;paid=0.0)
    nrPayment > installment.payments |> length && return paid
    payment = installment.payments[nrPayment]
    payment.first > date && return paid
    amountPaid = present_value(payment.second,loan.rate,payment.first,installment.dueDate,period=loan.period)
    paid .+= amount_paid
    paid < installment.dueValue && return amount_paid(loan,installment,date,nrPayment+1,paid=paid)
    
end

"""
    value_at_date(loan::LoanAgreement,installment::Installment,date::Dates.Date)
    
Return the present value of the non-paid installment or the paid value before the `date`.
""" 
function value_at_date(loan::LoanAgreement,installment::Installment,date::Dates.Date)
    open = installment.dueValue - amount_paid(loan,installment,date,1)
    paid = sum(x->x.second * (x.first <=date),installment.payments)
    paid+present_value(open,loan.rate,installment.dueDate,date;period= loan.period)
end


"""
    value_at_date(loan::LoanAgreement,date::Dates.Date)
    
Return the present value of the non-paid plus the amount paid until the `date` of a `loan` agreement.
""" 
function value_at_date(loan::LoanAgreement,date::Dates.Date)
    map(installment->value_at_date(loan,installment,date),loan.installments) |> sum
end

end

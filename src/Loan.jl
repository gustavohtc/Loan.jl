module Loan

import Dates, BusinessDays
import Base:isless,getindex, lastindex, iterate
export present_value, installment, due_dates

const DAYS_OF_PERIOD=Dict(Dates.Day=>1,Dates.Month=>30,Dates.Year=>365.25)
abstract type AbstractLoan; end
abstract type AbstractInstallments; end

mutable struct Installment{T <: Dates.DatePeriod}
    number::Number
    agreementDate::Dates.Date
    dueDate::Dates.Date
    dueValue::Float64
    rate::Float64
    period::Type{T}
    payments::AbstractVector{Pair{Dates.Date,Float64}}
end
mutable struct Installments{T <: Dates.DatePeriod} <: AbstractInstallments
    installments :: AbstractVector{Installment{T}} 
end
mutable struct PriceInstallments{T <: Dates.DatePeriod} <: AbstractInstallments
    nper ::Number
    agreementDate::Dates.Date
    dueDates::AbstractVector{Dates.Date}
    dueValue::Float64
    rate ::Float64
    period::Type{T}
    payments::AbstractVector{Pair{Dates.Date,Float64}}
end
function Base.getindex(ins::PriceInstallments,i)
    i <0 || i > ins.nper && throw(BoundsError(ins,i))
    Installment(
        i,
        ins.agreementDate,
        ins.dueDates[i],
        ins.dueValue,
        ins.rate,
        ins.period,
        Pair{Dates.Date,Float64}[]
    )
end
function Base.getindex(ins::Installments,i)
    ins.installments[i]
end
Base.firstindex(ins::AbstractInstallments)= 1

Base.lastindex(ins::AbstractInstallments)= 1
Base.lastindex(ins::PriceInstallments)  = ins.nper
Base.length(ins::PriceInstallments) = ins.nper
Base.length(ins::Installments)= ins.installments |> length
Base.iterate(ins::T,state) where T<:AbstractInstallments = state > length(ins) ? nothing : (ins[state],state+1) 
Base.iterate(ins::T) where T<:AbstractInstallments = (ins[firstindex(ins)],2) 
Base.isless(a::Installment,b::Installment) = a.dueDate < b.dueDate
function Base.merge(x::Installment,ls_y...)
    y= merge(ls_y...)
    x.dueDate!== y.dueDate && error("two installments must have the same due date to be summed.")
    vl_x = present_value(x.dueValue,x.rate,x.dueDate,x.agreementDate)
    vl_y = present_value(y.dueValue,y.rate,y.dueDate,y.agreementDate)
    Installment(
        -1,
        min(x.agreementDate, y.agreementDate),
        x.dueDate,
        x.dueValue+y.dueValue,
        (x.rate * vl_x + y.rate * vl_y)/(vl_x+vl_y),
        x.period,
        x.payments
    )
end 
Base.merge(x::Installment) = x

struct LoanAgreement{T <: Dates.DatePeriod} <:AbstractLoan
    amount::Number
    date::Dates.Date
    rate::Number
    period::Type{T}
    installments::Installments{T}
end

function LoanAgreement(amount,rate,agreementDate,dates::AbstractArray,nper;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates = @view dates[1:nper]
    installmentValue = installment(amount,rate,agreementDate,dueDates,period=period)
    installments = map((dt,nr)-> Installment(nr,agreementDate,dt,installmentValue,rate,period,Pair{Dates.Date,Float64}[]),dueDates,1:nper)
    LoanAgreement(amount,agreementDate,rate,period,Installments(installments))
end

function LoanAgreement(amount,rate,agreementDate,firstDueDate,nper;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates::Vector{Dates.Date} = [firstDueDate;due_dates(firstDueDate,nper-1,calendar,period=period)]
    LoanAgreement(amount,rate,agreementDate,dueDates,nper,calendar = calendar,period=period)
end


struct PriceLoanAgreement{T <: Dates.DatePeriod,W<:AbstractInstallments} <:AbstractLoan
    amount::Number
    date::Dates.Date
    rate::Number
    period::Type{T}
    installments::W
end


function PriceLoanAgreement(amount,rate,agreementDate,dates::AbstractVector,nper;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates = @view dates[1:nper]
    installmentValue = installment(amount,rate,agreementDate,dueDates,period=period)
    installments = PriceInstallments(nper,agreementDate,dueDates,installmentValue,rate,period,Pair{Dates.Date, Float64}[]) 
    PriceLoanAgreement(amount,agreementDate,rate,period,installments)
end

function PriceLoanAgreement(amount,rate,agreementDate,firstDueDate,nper;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates::Vector{Dates.Date} = [firstDueDate;due_dates(firstDueDate,nper-1,calendar,period=period)]
    PriceLoanAgreement(amount,rate,agreementDate,dueDates,nper,calendar=calendar,period=period)
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
factor_price(rate,qtPeriods) = 1/(1+rate)^(qtPeriods)

factor_price(rate) = (qtPeriods)->factor_price(rate,qtPeriods)

"""
    due_dates(initialDate::Dates.Date,nper::Number,calendar::Symbol;period=Dates.Month,grace=0)

Return `nper` of due dates after `initialDate` + `grace` period (in days) that is a business day in `calendar`
"""
function due_dates(initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month,grace=0) where T<: BusinessDays.HolidayCalendar
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
    fp = factor_price(rate)
    amount/sum(map(fp,qtsPeriods))
end

"""
    amount_paid(loan::LoanAgreement,installment::Installment,date::Dates.Date,payment::Pair{Dates.Date,Float64})
    
Return the amount already paid of a `installment` until a `date`.
""" 
function amount_paid(installment::Installment,date::Dates.Date,nrPayment::Number;paid=0.0)
    nrPayment > installment.payments |> length && return paid
    payment = installment.payments[nrPayment]
    payment.first > date && return paid
    amountPaid = present_value(payment.second,installment.rate,payment.first,installment.dueDate,period=installment.period)
    paid .+= amount_paid
    paid < installment.dueValue && return amount_paid(installment,date,nrPayment+1,paid=paid)
    
end

"""
    value_at_date(installment::Installment,date::Dates.Date)
    
Return the present value of the non-paid installment or the paid value before the `date`.
""" 
function value_at_date(installment::Installment,date::Dates.Date;regularPayment=regularPayment)
    regularPayment && installment.agreementDate > date && return (0.0,present_value(installment.dueValue,installment.rate,installment.dueDate,installment.agreementDate;period= installment.period))
    installment.agreementDate > date && !regularPayment && return (0.0,0.0)
    open = installment.dueValue - amount_paid(installment,date,1)
    paid = sum(x->x.second * (x.first <=date),installment.payments,init=0.0)
    regularPayment && installment.dueDate <= date && return (paid+open,0.0)
    (paid,present_value(open,installment.rate,installment.dueDate,date;period= installment.period))
end


"""
    value_at_date(loan::LoanAgreement,date::Dates.Date)
    
Return the present value of the non-paid plus the amount paid until the `date` of a `loan` agreement.
""" 
function value_at_date(loan::AbstractLoan,date::Dates.Date;justUnpaid=false,regularPayment=false)
    map(installment->begin 
        (paid,present) = value_at_date(installment,date,regularPayment = regularPayment)
        justUnpaid && return present
        paid+present
    end,loan.installments) |> sum
end


function revenue(loan,from::Dates.Date,until::Dates.Date)
    value_at_date(loan,until,regularPayment=true)-value_at_date(loan,from,regularPayment=true)
end

"""
    merge_loan(a::LoanAgreement,b::LoanAgreement)
    
Merge two LoanAgreements `a` an `a`, resulting a new LoanAgreement which cash flow is equals to the sum of `a` and `b`. 
"""
function merge_loan(a::AbstractLoan,b::AbstractLoan)
    parcs = sort([map(x->x,a.installments);map(x->x,b.installments)])
    dates = unique(map(x -> x.dueDate,parcs))
    installs = map(x -> merge(filter(p-> p.dueDate == x, parcs)...),dates)
    LoanAgreement(
        a.amount + b.amount,
        min(a.date,b.date),
        (a.rate * a.amount + b.rate * b.amount)/(a.amount+b.amount),
        a.period,
        Installments(installs)
    )
end

"""
    total_month_installment(loan::T, month::Dates.Date) where T<:LoanAgreement
    
The total value due of the `loan` by the `month`
"""
function total_month_installment(loan :: T,month::Dates.Date) where T<: LoanAgreement
    sum(x->x.dueValue,filter(x->trunc(x.dueDate,Dates.Month)==month,loan.installments),init=0.0)
end

function total_month_installment(loans::Vector{T},month::Dates.Date) where T<:LoanAgreement
    total_month_installment.(loans,month)
end

total_month_installment(month::Dates.Date) = (loan)->total_month_installment(loan,month)



"""
    value_by_pmt(pmt::Number,nper::Number,rate::Number,initialDate::Dates.Date,firstDueDate::Dates.Date;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    
Which value results in a regular payments of `pmt` if paid in `n` constant installments discounted by the `rate`. 
"""
function value_by_pmt(pmt::Number,nper::Number,rate::Number,initialDate::Dates.Date,firstDueDate::Dates.Date;calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates = [firstDueDate;due_dates(firstDueDate,nper-1,calendar,period=period)]
    qtsPeriods = days_between.(dueDates,initialDate) ./ DAYS_OF_PERIOD[period]
    fp = factor_price(rate)
    pmt*sum(map(fp,qtsPeriods))
end

function value_by_pmt(pmt::Number,nper::Number,rate::Number,initialDate::Dates.Date,dates::Vector{Dates.Date};calendar=BusinessDays.NullHolidayCalendar(),period=Dates.Month)
    dueDates = @view dates[1:nper]
    qtsPeriods = days_between.(dueDates,initialDate) ./ DAYS_OF_PERIOD[period]
    fp = factor_price(rate)
    pmt*sum(map(fp,qtsPeriods))
end



end

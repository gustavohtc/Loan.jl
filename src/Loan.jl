module Loan

import Dates, BusinessDays

export present_value, pmt

const DAYS_OF_PERIOD=Dict(Dates.Day=>1,Dates.Month=>30,Dates.Year=>365.25)

struct LoanAgreement
    amount::Number
    rate::Number
    dueCashFlow::Dict{Dates.Date,Number}
    paidCashFlow::Dict{Dates.Date,Number}
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



factor_price(rate,qtPeriods,qtPeriodsFirst) = 1/(1+rate)^(qtPeriods+qtPeriodsFirst-1)
factor_price(rate,qtPeriodsFirst) = (qtPeriods)->factor_price(rate,qtPeriods,qtPeriodsFirst)

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
    pmt(amount::Number,rate::Number,initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month) where T<: BusinessDays.HolidayCalendar

Return the constant payment value required to settle a loan (`amount`) with a fixed `rate` agreed at `initialDate` in `nper` payments
"""

function pmt(amount::Number,rate::Number,initialDate::Dates.Date,nper::Number,calendar::Union{Symbol,T}=BusinessDays.NullHolidayCalendar();period=Dates.Month,grace=0) where T<: BusinessDays.HolidayCalendar
    dueDates = due_dates(initialDate,nper,calendar,period=period,grace=grace)
    pmt(amount,rate,initialDate,dueDates,period=period)
end

"""
    pmt(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period=Dates.Month)

Return the constant payment value required to settle a loan (`amount`) with a fixed `rate` with `dueDates` payments flow
"""

function pmt(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period=Dates.Month)
    qtsPeriods = days_between.(dueDates,initialDate) ./ DAYS_OF_PERIOD[period]
    qtPeriodsFirst = minimum(qtsPeriods)
    fp = factor_price(rate,qtPeriodsFirst)
    amount/sum(map(fp,qtsPeriods))
end



end

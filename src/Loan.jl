module Loan

import Dates

export present_value

const DAYS_OF_PERIOD=Dict("day"=>1,"month"=>30,"year"=>365.25)


"""
    present_value(amount,rate,dueDate,presentDate;period="month")

Return the value at presentDate of value of the `amount` due to `dueDate` discounted by the `rate`.
"""

function present_value(amount,rate,dueDate,presentDate;period="month")
    period ∉ keys(DAYS_OF_PERIOD) && error("Period not defined, must be $(join(keys(DAYS_OF_PERIOD),", "," or "))")
    amount*(1+rate)^((presentDate-dueDate).value/DAYS_OF_PERIOD[period])
end

"""
    present_value(amount,rate,dueDate;period="month")

Return the present value of the `amount` due to `dueDate` discounted by the `rate`.
"""

present_value(amount,rate,dueDate;period="month")= present_value(amount,rate,dueDate,Dates.today(),period=period)



factor_price(rate,qtPeriods,qtPeriodsFirst) = 1/(1+rate)^(qtPeriods+qtPeriodsFirst-1)
factor_price(rate,qtPeriodsFirst) = (qtPeriods)->factor_price(rate,qtPeriods,qtPeriodsFirst)

"""
    pmt(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period="month")

Return the constant payment value required to settle a loan (`amount`) with a fixed `rate` with `dueDates` payments flow
"""

function pmt(amount::Number,rate::Number,initialDate::Dates.Date,dueDates::AbstractVector{Dates.Date};period="month")
    qtsPeriods = dueDates .|> dueDate-> (dueDate-initialDate).value/DAYS_OF_PERIOD[period]
    qtPeriodsFirst = minimum(qtDays)
    fp = factor_price(rate,qtPeriodsFirst)
    amount/sum(map(fp,qtsPeriods))
end


end

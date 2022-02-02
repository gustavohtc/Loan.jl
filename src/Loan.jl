module Loan

import Dates

export present_value

const DAYS_OF_PERIOD=Dict("day"=>1,"month"=>30,"year"=>365.25)


"""
    present_value(amount,rate,dueDate,presentDate=Dates.today())

Return the present value of the `amount` due to `dueDate` discounted by the `rate`.

"""

function present_value(amount,rate,dueDate,presentDate;period="month")
    period ∉ keys(DAYS_OF_PERIOD) && error("Period not defined, must be $(join(keys(DAYS_OF_PERIOD),", "," or "))")
    amount*(1+rate)^((presentDate-dueDate).value/DAYS_OF_PERIOD[period])
end
present_value(amount,rate,dueDate;period="month")= present_value(amount,rate,dueDate,Dates.today(),period=period)


end

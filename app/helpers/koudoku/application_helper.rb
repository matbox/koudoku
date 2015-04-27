module Koudoku
  module ApplicationHelper

    def plan_price(plan)
      "#{number_to_currency(plan.price)}/#{plan_interval(plan)}"
    end

    def plan_interval(plan)
      case plan.interval
      when "Monat"
        "month"
      when "Jahr"
        "year"
      when "Woche"
        "week"
      when "Halbjährig"
        "half-year"
      when "Vierteljährlich"
        "quarter"
      else
        "month"
      end
    end

  end
end

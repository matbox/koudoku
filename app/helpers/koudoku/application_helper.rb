module Koudoku
  module ApplicationHelper

    def plan_price(plan)
      "#{number_to_currency(plan.price)}/#{plan_interval(plan)}"
    end

    def plan_interval(plan)
      case plan.interval
      when "Monat"
        "Monat"
      when "Jahr"
        "Jahr"
      when "Woche"
        "Woche"
      when "Halbjährig"
        "Halbjährig"
      when "Vierteljährlich"
        "Vierteljährlich"
      else
        "Monat"
      end
    end

  end
end

# Copied with little modifications from: https://github.com/rubinius/rubinius-benchmark/blob/master/real_world/bench_degree_days.rb

class DegreeDays

  def initialize(@daily_temperatures, @options = {} of Symbol => Float)
  end

  property :daily_temperatures

  def calculate
    heating = 0.0
    cooling = 0.0
    heating_days = 0.0
    cooling_days = 0.0

    daily_temperatures.each do |day|
      heating_today = heating_day(day)
      cooling_today = cooling_day(day)

      if heating_today
        heating_days += 1
        heating += heating_today
      end

      if cooling_today
        cooling_days += 1
        cooling += cooling_today
      end
    end

    {
      :heating => heating,
      :cooling => cooling,
      :heating_days => heating_days,
      :cooling_days => cooling_days
    }
  end

#private

  def sum(ary)
    ary.inject(0) { |a,i| a + i }
  end

  def avg(ary)
    sum(ary).to_f / ary.size.to_f
  end

  def heating_day(temps)
    heat = avg temps.map {|temp| heating_degree(temp)}
    (heat > heating_threshold) ? heat : nil
  end

  def cooling_day(temps)
    cool = avg temps.map {|temp| cooling_degree(temp)}
    (cool > cooling_threshold) ? cool : nil
  end

  def heating_degree(temp)
    deg = base_temperature - (temp + heating_insulation)
    [deg, 0].max
  end

  def cooling_degree(temp)
    deg = (temp - cooling_insulation) - base_temperature
    [deg, 0].max
  end

  def base_temperature
    @options[:base_temperature]? || 65.0
  end

  def heating_insulation
    @options[:heating_insulation]? || insulation_factor || 3
  end

  def cooling_insulation
    @options[:cooling_insulation]? || insulation_factor || 0
  end

  def insulation_factor
    @options[:insulation_factor]?
  end

  def heating_threshold
    @options[:heating_threshold]? || threshold || 6
  end

  def cooling_threshold
    @options[:cooling_threshold]? || threshold || 3
  end

  def threshold
    @options[:threshold]?
  end

end

(ARGV[0]? || 300).to_i.times do |i|
  days_in_year = 365
  hours_in_day = 24

  hot_day = Array.new(hours_in_day, 92)
  cold_day = Array.new(hours_in_day, 37)

  temperatures = Array.new((days_in_year / 2.0).floor, hot_day) + # 182 hot days
    Array.new((days_in_year / 2.0).ceil, cold_day)   # 183 cold days

  degree_days = DegreeDays.new(temperatures)
  res = degree_days.calculate
  p res if i == 0
end


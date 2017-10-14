# :nodoc:
module Time::Format::CompositeTerms
  def date_and_time
    short_day_name
    char ' '
    short_month_name
    char ' '
    day_of_month_blank_padded
    char ' '
    twenty_four_hour_time_with_seconds
    char ' '
    year
  end

  def date
    month_zero_padded
    char '/'
    day_of_month_zero_padded
    char '/'
    year_modulo_100
  end

  def year_month_day
    year
    char '-'
    month_zero_padded
    char '-'
    day_of_month_zero_padded
  end

  def twelve_hour_time
    hour_12_zero_padded
    char ':'
    minute
    char ':'
    second
    char ' '
    am_pm_upcase
  end

  def twenty_four_hour_time
    hour_24_zero_padded
    char ':'
    minute
  end

  def twenty_four_hour_time_with_seconds
    hour_24_zero_padded
    char ':'
    minute
    char ':'
    second
  end
end

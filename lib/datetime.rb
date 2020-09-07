require 'time'

def millisecondsToHours(t)
  # Round up to the nearest hundredth of an hour
  # We could go to whole hours, tenths, or even thousandths, simply by moving zeroes, but hundredths works for me
  (t.to_f / 36000).ceil.to_f / 100
end

# format a date range (e.g. September 1 - 15, 2013)
def formatDateRange(start_date_str, end_date_str)
  start_date = Date.parse(start_date_str)
  end_date = Date.parse(end_date_str)
  if start_date.year != end_date.year
    return start_date.strftime('%B %e, %Y') + ' - ' + end_date.strftime('%B %e, %Y')
  elsif start_date.month != end_date.month
    return start_date.strftime('%B %e') + ' - ' + end_date.strftime('%B %e, %Y')
  elsif start_date.day != end_date.day
    return start_date.strftime('%B %e') + ' - ' + end_date.strftime('%e, %Y')
  else
    return start_date.strftime('%B %e, %Y')
  end
end

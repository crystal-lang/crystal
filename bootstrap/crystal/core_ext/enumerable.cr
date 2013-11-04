module Enumerable
  def to_s_with_line_numbers
    map_with_index { |line, i| "#{"%3d" % (i + 1)}. #{line.to_s.chomp}" }.join "\n"
  end
end

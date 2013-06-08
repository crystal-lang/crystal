class Array
  def to_s_with_line_numbers
    each_with_index.map { |line, i| "#{'%3d' % (i + 1)}. #{line.to_s.chomp}" }.join "\n"
  end
end
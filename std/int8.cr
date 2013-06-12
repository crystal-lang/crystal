class Int8
  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhd", self)
    end
  end
end
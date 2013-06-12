class Int16
  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hd", self)
    end
  end
end
class UInt8
  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhu", self)
    end
  end
end
class UInt16
  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hu", self)
    end
  end
end
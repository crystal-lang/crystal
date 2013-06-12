class UInt64
  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%lu", self)
    end
  end
end
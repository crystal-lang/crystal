class UInt16
  MIN = 0_u16
  MAX = 65535_u16

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hu", self)
    end
  end
end
class UInt8
  MIN = 0_u8
  MAX = 255_u8

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhu", self)
    end
  end
end
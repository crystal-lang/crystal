class UInt32
  MIN = 0_u32
  MAX = 4294967295_u32

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%u", self)
    end
  end
end

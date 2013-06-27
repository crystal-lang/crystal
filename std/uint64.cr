class UInt64
  MIN = 0_u64
  MAX = 18446744073709551615_u64

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%lu", self)
    end
  end
end
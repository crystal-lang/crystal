lib C
  alias SizeT = UInt64
end

class Int
  def to_sizet
    to_u64
  end
end

class UInt64
  def to_sizet
    self
  end
end

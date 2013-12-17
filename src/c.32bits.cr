lib C
  alias SizeT = UInt32
end

class Int
  def to_sizet
    to_u32
  end
end

class UInt32
  def to_sizet
    self
  end
end

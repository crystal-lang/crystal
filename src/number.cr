struct Number
  def step(limit, step = 1)
    x = self
    if step > 0 && self < limit
      while x <= limit
        yield x
        x += step
      end
    elsif step < 0 && self > limit
      while x >= limit
        yield x
        x += step
      end
    end
    self
  end

  def abs
    self < 0 ? -self : self
  end

  def divmod(number)
    {self / number, self % number}
  end

  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end

  macro generate_to_s(capacity, format)
    def to_s
      String.new_with_capacity({{capacity}}) do |buffer|
        C.sprintf(buffer, {{format}}, self)
      end
    end

    def to_s(io)
      chars :: UInt8[{{capacity}}]
      chars.set_all_to 0_u8
      C.sprintf(chars.buffer, {{format}}, self)
      io.append_c_string(chars.buffer)
    end
  end
end

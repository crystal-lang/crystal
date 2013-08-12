class Object
  def !=(other)
    !(self == other)
  end

  def ===(other)
    self == other
  end

  def inspect
    to_s
  end

  def tap
    yield self
    self
  end

  def instance_eval
    self.yield
  end
end

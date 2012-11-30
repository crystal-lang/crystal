class Object
  def inspect
    to_s
  end

  def tap
    yield self
    self
  end
end
class Bool
  def ==(other)
    false
  end

  def |(other : Bool)
    self ? true : other
  end

  def &(other : Bool)
    self ? other : false
  end

  def to_s
    self ? "true" : "false"
  end
end
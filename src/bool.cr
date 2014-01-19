struct Bool
  def !@
    self ? false : true
  end

  def ==(other)
    false
  end

  def |(other : Bool)
    self ? true : other
  end

  def &(other : Bool)
    self ? other : false
  end

  def hash
    self ? 1 : 0
  end

  def to_s
    self ? "true" : "false"
  end
end

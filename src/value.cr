struct Value
  def ==(other)
    false
  end

  def !
    false
  end

  def nil?
    false
  end

  def clone
    self
  end
end


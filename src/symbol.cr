struct Symbol
  def ==(other)
    false
  end

  def inspect
    ":#{to_s}"
  end
end

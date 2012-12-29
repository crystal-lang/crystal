class Bool
  def ==(other)
    false
  end

  def to_s
    self ? "true" : "false"
  end
end
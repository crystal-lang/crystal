class String
  def to_i
    C.atoi self
  end

  def to_s
    self
  end
end
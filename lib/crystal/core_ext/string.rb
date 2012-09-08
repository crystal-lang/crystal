class String
  def var
    Crystal::Var.new self
  end

  def call(*args)
    Crystal::Call.new nil, self, args
  end
end

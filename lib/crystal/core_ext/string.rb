class String
  def var
    Crystal::Var.new self
  end

  def ref
    Crystal::Ref.new self
  end
end

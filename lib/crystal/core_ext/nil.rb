class NilClass
  def type_id
    0
  end

  def clone(*)
    nil
  end
end
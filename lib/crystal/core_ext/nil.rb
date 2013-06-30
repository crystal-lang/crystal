class NilClass
  def type_id
    -1
  end

  def clone(*)
    nil
  end
end
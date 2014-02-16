class Reference
  def ==(other : Value)
    false
  end

  def ==(other : Reference)
    same?(other)
  end

  def same?(other : Reference)
    object_id == other.object_id
  end

  def nil?
    false
  end

  def !
    false
  end

  def hash
    object_id
  end

  def clone
    self
  end

  def to_s
    String.new(to_cstr)
  end
end

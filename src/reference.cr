class Reference
  def ==(other : self)
    same?(other)
  end

  def ==(other)
    false
  end

  def same?(other : Reference)
    object_id == other.object_id
  end

  def same?(other : Nil)
    false
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

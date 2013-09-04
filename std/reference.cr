class Reference
  macro self.getter(name)"
    def #{name}
      @#{name}
    end
  "end

  macro self.setter(name)"
    def #{name}=(@#{name})
    end
  "end

  macro self.property(name)"
    getter :#{name}
    setter :#{name}
  "end

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

  def !@
    false
  end

  def hash
    object_id
  end

  def clone
    self
  end

  def to_s
    String.from_cstr(to_cstr)
  end
end

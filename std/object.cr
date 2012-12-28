class Object
  macro self.attr_reader(name)"
    def #{name}
      @#{name}
    end
  "end

  macro self.attr_writer(name)"
    def #{name}=(value)
      @#{name} = value
    end
  "end

  macro self.attr(name)"
    attr_reader :#{name}
    attr_writer :#{name}
  "end

  macro self.attr_accessor(symbol_or_name)"
    attr :#{symbol_or_name}
  "end

  def !=(other)
    !(self == other)
  end

  def ==(other : Value)
    false
  end

  def ==(other)
    same?(other)
  end

  def same?(other)
    Object.same?(self, other)
  end

  def self.same?(object1, object2)
    object1.object_id == object2.object_id
  end

  def ===(other)
    self == other
  end

  def !@
    false
  end

  def to_b
    true
  end

  def to_s
    String.from_cstr(to_cstr)
  end

  def inspect
    to_s
  end

  def tap
    yield self
    self
  end

  def ||(other)
    self
  end

  def &&(other)
    other
  end
end
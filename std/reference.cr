class Reference
  macro self.attr(name)"
    attr_reader :#{name}
  "end

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

  macro self.attr_accessor(name)"
    attr_reader :#{name}
    attr_writer :#{name}
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

  def !@
    nil?
  end

  def to_s
    String.from_cstr(to_cstr)
  end
end
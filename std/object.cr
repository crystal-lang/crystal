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

  def to_b
    true
  end

  def inspect
    to_s
  end

  def tap
    yield self
    self
  end
end
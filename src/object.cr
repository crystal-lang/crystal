class Object
  def !=(other)
    !(self == other)
  end

  def ===(other)
    self == other
  end

  def inspect
    to_s
  end

  def tap
    yield self
    self
  end

  def instance_eval
    self.yield
  end

  def try
    yield self
  end

  def not_nil!
    self
  end

  macro getter(name)"
    def #{name}
      @#{name}
    end
  "end

  macro getter!(name)"
    def #{name}?
      @#{name}
    end

    def #{name}
      @#{name}.not_nil!
    end
  "end

  macro setter(name)"
    def #{name}=(@#{name})
    end
  "end

  macro property(name)"
    getter :#{name}
    setter :#{name}
  "end

  macro property!(name)"
    getter! :#{name}
    setter :#{name}
  "end

  macro delegate(method, to)"
    def #{method}
      #{to}.#{method}
    end
  "end
end

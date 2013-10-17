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

  def try!
    yield self
  end

  def not_nil!
    self
  end

  macro self.getter(name)"
    def #{name}
      @#{name}
    end
  "end

  macro self.getter!(name)"
    def #{name}?
      @#{name}
    end

    def #{name}
      @#{name}.not_nil!
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

  macro self.property!(name)"
    getter! :#{name}
    setter :#{name}
  "end

  macro self.delegate(method, to)"
    def #{method}
      #{to}.#{method}
    end
  "end
end

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
    with self yield
  end

  def try
    yield self
  end

  def not_nil!
    self
  end

  macro getter(name)
    def {{name.id}}
      @{{name.id}}
    end
  end

  macro getter!(name)
    def {{name.id}}?
      @{{name.id}}
    end

    def {{name.id}}
      @{{name.id}}.not_nil!
    end
  end

  macro setter(name)
    def {{name.id}}=(@{{name.id}})
    end
  end

  macro property(name)
    getter :{{name.id}}
    setter :{{name.id}}
  end

  macro property!(name)
    getter! :{{name.id}}
    setter :{{name.id}}
  end

  macro delegate(method, to)
    def {{method.id}}
      {{to.id}}.{{method.id}}
    end
  end
end

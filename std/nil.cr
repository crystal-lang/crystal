class Nil
  def object_id
    0
  end

  def ==(other : Nil)
    true
  end

  def ==(other)
    false
  end

  def nil?
    true
  end

  def !@
    true
  end

  def hash
    0
  end

  def to_i
    0
  end

  def to_s
    ""
  end

  def inspect
    "nil"
  end

  def method_missing(name, args)
    if args
      raise "Called #{name}(#{args.join ", "}) for nil"
    else
      raise "Called #{name} for nil"
    end
  end
end
class Nil
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
    puts "Called #{name}(#{args.join ", "}) for nil"
    exit 1
    nil
  end
end
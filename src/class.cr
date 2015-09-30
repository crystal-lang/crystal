class Class
  def inspect(io)
    to_s(io)
  end

  def hash
    crystal_type_id
  end

  def ==(other : Class)
    crystal_type_id == other.crystal_type_id
  end

  def ===(other)
    other.is_a?(self)
  end

  # Returns the name of this class.
  #
  # ```
  # String.name #=> "String"
  # ```
  macro def name : String
    {{ @type.name.stringify }}
  end

  def to_s(io)
    io << name
  end
end

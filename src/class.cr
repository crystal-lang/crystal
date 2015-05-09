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

  macro def name : String
    {{ @type.name.ends_with?(":Class") ? @type.name[0..-7].id.stringify : @type.name.id.stringify }}
  end

  def to_s(io)
    io << name
  end
end

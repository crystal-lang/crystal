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
    {{ @class_name.ends_with?(":Class") ? @class_name[0..-7] : @class_name }}
  end

  def to_s(io)
    io << name
  end
end
